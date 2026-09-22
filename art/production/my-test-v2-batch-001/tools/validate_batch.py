#!/usr/bin/env python3
"""Read-only production-template checks. This does not run Godot or approve art.

Requires Python 3.9+. No third-party packages or network access are required.
Exit status: 0 = requested static gate passed; 1 = validation failure.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import sys
from typing import Any

ASSET_STATES = {
    'planned', 'generated', 'normalized', 'registered', 'qa_pass',
    'game_verified', 'user_approved', 'needs_revision', 'blocked',
}
QA_STATES = {'NOT_RUN', 'PASS', 'FAIL', 'BLOCKED', 'NOT_APPLICABLE'}
HEX64 = re.compile(r'^[0-9a-fA-F]{64}$')
COMMIT = re.compile(r'^[0-9a-fA-F]{40}([0-9a-fA-F]{24})?$')
IDENT = re.compile(r'^[a-z][a-z0-9_.-]*$')
QA_FIELDS = ('technical', 'assembly_visual', 'save_reload', 'wear_opening',
             'headgear_opening', 'motion', 'game_consistency')


def read_json(path: Path) -> dict[str, Any]:
    with path.open('r', encoding='utf-8-sig') as stream:
        obj = json.load(stream)
    if not isinstance(obj, dict):
        raise ValueError(f'{path.name}: top level must be an object')
    return obj


def finite_vector(value: Any, length: int, positive: bool = False) -> bool:
    return (
        isinstance(value, list) and len(value) == length
        and all(isinstance(x, (int, float)) and not isinstance(x, bool)
                and math.isfinite(x) and (not positive or x > 0) for x in value)
    )


class Validator:
    def __init__(self, root: Path | None):
        self.root = root.resolve() if root else None
        self.errors: list[str] = []
        self.digest_cache: dict[Path, str] = {}

    def check(self, condition: bool, message: str) -> bool:
        if not condition:
            self.errors.append(message)
        return condition

    def file(self, record: Any, context: str, hash_required: bool = True) -> None:
        if not self.check(isinstance(record, dict), f'{context}: missing file record'):
            return
        raw = record.get('path')
        if not self.check(isinstance(raw, str) and bool(raw.strip()),
                          f'{context}: path is not filled'):
            return
        assert self.root is not None
        relative = Path(raw)
        if not self.check(not relative.is_absolute() and ':' not in raw and '\\' not in raw,
                          f'{context}: use a project-root-relative path with / separators'):
            return
        full = (self.root / relative).resolve()
        if not self.check(full == self.root or self.root in full.parents,
                          f'{context}: path escapes project root'):
            return
        if not self.check(full.is_file(), f'{context}: file does not exist: {raw}'):
            return
        supplied = record.get('sha256')
        if not hash_required and supplied is None:
            return
        if not self.check(isinstance(supplied, str) and HEX64.fullmatch(supplied) is not None,
                          f'{context}: missing or invalid SHA-256'):
            return
        try:
            if full not in self.digest_cache:
                digest = hashlib.sha256()
                with full.open('rb') as stream:
                    for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                        digest.update(chunk)
                self.digest_cache[full] = digest.hexdigest()
            self.check(self.digest_cache[full] == supplied.lower(),
                       f'{context}: recorded SHA-256 does not match file bytes')
        except OSError as error:
            self.errors.append(f'{context}: cannot read file: {error}')

    def evidence(self, records: Any, context: str) -> None:
        if not self.check(isinstance(records, list) and bool(records),
                          f'{context}: no actual evidence file is registered'):
            return
        for index, record in enumerate(records):
            self.file(record, f'{context}[{index}]', hash_required=False)


def validate(batch: Path, gate: str, root: Path | None) -> tuple[Validator, dict[str, Any]]:
    v = Validator(root)
    m = read_json(batch / 'manifest.json')
    p = read_json(batch / 'presets.json')
    q = read_json(batch / 'qa_matrix.json')
    v.check(m.get('manifest_schema') == 'fb-art-production-batch/1', 'Unsupported manifest_schema')
    v.check(p.get('preset_schema') == 'fb-art-review-presets/1', 'Unsupported preset_schema')
    v.check(q.get('qa_schema') == 'fb-art-qa-matrix/1', 'Unsupported qa_schema')
    v.check(p.get('batch_id') == q.get('batch_id') == m.get('batch_id'), 'Batch IDs disagree')

    assets, presets, cases = m.get('assets'), p.get('presets'), q.get('cases')
    for label, values in [('assets', assets), ('presets', presets), ('cases', cases)]:
        if not v.check(isinstance(values, list) and all(isinstance(x, dict) for x in values),
                       f'{label} must be a list of objects'):
            return v, {}

    ids = [a.get('asset_id') for a in assets]
    if not v.check(all(isinstance(x, str) and IDENT.fullmatch(x) for x in ids),
                   'Every asset_id must be a nonempty stable identifier'):
        return v, {}
    v.check(len(ids) == len(set(ids)), 'Duplicate asset_id')
    by_id = {a['asset_id']: a for a in assets}
    id_set = set(ids)
    counts = m.get('counts', {})
    v.check(isinstance(counts, dict), 'counts must be an object')
    if not isinstance(counts, dict): counts = {}
    v.check(len(assets) == counts.get('expected_logical_assets'), 'Logical asset count is incorrect')
    designs = [a.get('design_id') for a in assets]
    v.check(all(isinstance(x, str) and bool(x) for x in designs), 'Missing design_id')
    if all(isinstance(x, str) for x in designs):
        v.check(len(set(designs)) == counts.get('expected_designs'), 'Design count is incorrect')
    hg_designs = {a.get('design_id') for a in assets if a.get('category') == 'headgear'}
    v.check(len(hg_designs) == counts.get('expected_headgear_designs'), 'Headgear design count is incorrect')

    part_ids: list[str] = []
    for a in assets:
        aid = a['asset_id']
        v.check(a.get('status') in ASSET_STATES, f'{aid}: unknown asset status')
        v.check(a.get('template_id') == m.get('template_id'), f'{aid}: template mismatch')
        deps = a.get('depends_on', [])
        v.check(isinstance(deps, list), f'{aid}: depends_on must be a list')
        if isinstance(deps, list):
            for dep in deps:
                v.check(isinstance(dep, str) and dep in id_set, f'{aid}: unknown dependency {dep}')
                v.check(dep != aid, f'{aid}: cannot depend on itself')
        pair_id = a.get('paired_asset_id')
        if pair_id is not None:
            if v.check(isinstance(pair_id, str) and pair_id in id_set, f'{aid}: missing paired asset'):
                pair = by_id[pair_id]
                v.check(pair.get('paired_asset_id') == aid, f'{aid}: pair is not reciprocal')
                v.check(pair.get('design_id') == a.get('design_id'), f'{aid}: paired design mismatch')
                v.check({pair.get('variant'), a.get('variant')} == {'intact', 'damaged'},
                        f'{aid}: pair must be intact/damaged')
        if a.get('variant') == 'damaged':
            v.check(pair_id is not None and isinstance(deps, list) and pair_id in deps,
                    f'{aid}: damaged asset must depend on its intact counterpart')
        parts = a.get('parts')
        if v.check(isinstance(parts, list) and bool(parts), f'{aid}: missing render-part plan'):
            for part in parts:
                if not v.check(isinstance(part, dict), f'{aid}: part must be an object'): continue
                part_id = part.get('part_id')
                if v.check(isinstance(part_id, str) and IDENT.fullmatch(part_id) is not None,
                           f'{aid}: invalid part_id'):
                    part_ids.append(part_id)
        qa = a.get('qa', {})
        if not v.check(isinstance(qa, dict), f'{aid}: missing qa object'): continue
        for field in QA_FIELDS:
            v.check(qa.get(field) in QA_STATES, f'{aid}: invalid {field} QA status')
        if a.get('category') == 'headgear':
            hp = a.get('headgear_policy')
            v.check(isinstance(hp, dict), f'{aid}: missing headgear policy')
        approval = a.get('user_approval', {})
        if not v.check(isinstance(approval, dict), f'{aid}: missing approval object'): continue
        if a.get('status') == 'user_approved' or approval.get('status') == 'APPROVED':
            v.check(approval.get('status') == 'APPROVED'
                    and bool(approval.get('by')) and bool(approval.get('at')) and bool(approval.get('reference')),
                    f'{aid}: user approval requires an actual reviewer, date and source')
    v.check(len(part_ids) == len(set(part_ids)), 'Duplicate part_id')

    preset_ids = [x.get('preset_id') for x in presets]
    if not v.check(all(isinstance(x, str) and x for x in preset_ids), 'Invalid preset_id'):
        return v, {}
    v.check(len(preset_ids) == len(set(preset_ids)), 'Duplicate preset_id')
    coverage: set[str] = set()
    planned_membership = {aid: set() for aid in id_set}
    for preset in presets:
        pid = preset['preset_id']
        selections = preset.get('selections')
        if not v.check(isinstance(selections, dict), f'{pid}: selections must be an object'): continue
        selected = [x for x in selections.values() if x is not None]
        for aid in selected:
            if v.check(isinstance(aid, str) and aid in id_set, f'{pid}: unknown asset reference {aid}'):
                coverage.add(aid)
                planned_membership[aid].add(pid)
        known = [by_id[x] for x in selected if isinstance(x, str) and x in by_id]
        slots = [x.get('slot') for x in known]
        v.check(len(slots) == len(set(slots)), f'{pid}: selects more than one asset for the same slot')
    v.check(coverage == id_set, 'Presets do not cover all assets: ' + ', '.join(sorted(id_set - coverage)))
    for a in assets:
        fit = a.get('assembly_fit', {})
        if not v.check(isinstance(fit, dict), f"{a['asset_id']}: missing assembly_fit"): continue
        links = fit.get('preset_ids')
        v.check(isinstance(links, list) and all(isinstance(x, str) for x in links),
                f"{a['asset_id']}: invalid preset_ids")
        if isinstance(links, list) and all(isinstance(x, str) for x in links):
            v.check(set(links) == planned_membership[a['asset_id']],
                    f"{a['asset_id']}: preset membership is stale")

    case_ids = [x.get('case_id') for x in cases]
    if not v.check(all(isinstance(x, str) and x for x in case_ids), 'Invalid case_id'):
        return v, {}
    v.check(len(case_ids) == len(set(case_ids)), 'Duplicate case_id')
    v.check(q.get('case_count') == len(cases), 'QA case_count is incorrect')
    for c in cases:
        cid = c['case_id']
        v.check(c.get('status') in QA_STATES, f'{cid}: unknown QA status')
        refs = c.get('asset_ids')
        if v.check(isinstance(refs, list), f'{cid}: asset_ids must be a list'):
            for aid in refs:
                v.check(isinstance(aid, str) and aid in id_set, f'{cid}: unknown asset reference {aid}')
        if c.get('status') in {'BLOCKED', 'FAIL', 'NOT_APPLICABLE'}:
            v.check(bool(c.get('reason')), f'{cid}: this result requires a reason')
        if c.get('status') == 'PASS':
            v.check(bool(c.get('evidence')) and bool(c.get('tested_revision')),
                    f'{cid}: PASS needs evidence and tested revision')

    # A plan can be structurally valid while containing no produced images at all.
    if gate != 'plan':
        baseline = m.get('baseline', {})
        v.check(isinstance(baseline.get('commit'), str)
                and COMMIT.fullmatch(baseline.get('commit', '')) is not None,
                'Baseline actual commit is missing or invalid')
        v.check(bool(baseline.get('captured_at')), 'Baseline capture time is missing')
        files = baseline.get('files', [])
        roles = {x.get('role') for x in files if isinstance(x, dict)}
        v.check({'user_calibration', 'catalog', 'modules'} <= roles, 'Baseline file roles are incomplete')
        for index, record in enumerate(files): v.file(record, f'baseline.files[{index}]')
        for field in ['source_pngs', 'motion_sources']:
            records = baseline.get(field)
            if v.check(isinstance(records, list) and bool(records), f'baseline.{field} is empty'):
                for index, record in enumerate(records): v.file(record, f'baseline.{field}[{index}]')
        v.check(baseline.get('resolved_motion_mode') in {'draft_actions', 'code_default', 'mixed'},
                'Baseline motion resolution mode is missing')
        bindings = baseline.get('bindings', {})
        for binding in ('base', 'skin', 'body', 'head', 'scar', 'bandage', 'blood'):
            v.check(bool(bindings.get(binding)), f'baseline.bindings.{binding} is unresolved')
        out = m.get('outputs', {})
        v.file(out.get('resolved_geometry_spec'), 'outputs.resolved_geometry_spec')
        v.file(out.get('assembly_package'), 'outputs.assembly_package')
        pack = out.get('assembly_package', {})
        v.check(bool(pack.get('assembly_revision')), 'Assembly version is missing')
        v.check(pack.get('transform_policy') in {'resolved_once', 'shared_resolver_delta'},
                'Unknown transform application policy')
        if gate == 'game': v.file(out.get('game_consistency_report'), 'outputs.game_consistency_report')

        for a in assets:
            aid = a['asset_id']
            accepted = {'game_verified', 'user_approved'} if gate == 'game' else {'qa_pass', 'game_verified', 'user_approved'}
            v.check(a.get('status') in accepted, f'{aid}: not at the requested {gate} gate')
            prov = a.get('provenance', {})
            v.file(prov.get('raw_output'), f'{aid}.raw_output')
            v.file({'path': prov.get('prompt_file')}, f'{aid}.prompt_file', hash_required=False)
            refs = prov.get('reference_files', [])
            if v.check(isinstance(refs, list) and bool(refs), f'{aid}: no actual reference files'):
                for index, record in enumerate(refs): v.file(record, f'{aid}.reference[{index}]')
            for field in ('tool', 'model', 'generated_at'):
                v.check(bool(prov.get(field)), f'{aid}: {field} must be filled (unknown is allowed when unavailable)')
            for part in a.get('parts', []):
                if not isinstance(part, dict): continue
                context = part.get('part_id', aid)
                v.file(part.get('file'), f'{context}.file')
                v.check(part.get('geometry_status') == 'resolved', f'{context}: geometry is unresolved')
                image = part.get('image_size_px'); rect = part.get('source_rect_px')
                image_ok = finite_vector(image, 2, True) and all(isinstance(x, int) for x in image)
                rect_ok = finite_vector(rect, 4) and all(isinstance(x, int) for x in rect)
                v.check(image_ok, f'{context}: invalid image_size_px')
                v.check(rect_ok, f'{context}: invalid source_rect_px')
                if image_ok and rect_ok:
                    x, y, width, height = rect
                    v.check(x >= 0 and y >= 0 and width > 0 and height > 0
                            and x + width <= image[0] and y + height <= image[1],
                            f'{context}: source rect is outside declared image bounds')
                v.check(finite_vector(part.get('logical_size_before_fit'), 2, True), f'{context}: invalid logical size')
                v.check(finite_vector(part.get('position_before_fit'), 2), f'{context}: invalid position')
                v.check(finite_vector(part.get('pivot_normalized'), 2), f'{context}: invalid pivot')
                v.check(bool(part.get('layer_relation')), f'{context}: layer relation is unresolved')
                v.check(part.get('parent_binding') not in (None, '', 'current_body_or_weapon_binding'),
                        f'{context}: parent binding is unresolved')
            fit = a.get('assembly_fit', {})
            v.check(fit.get('status') == 'PASS' and bool(fit.get('fit_revision')),
                    f'{aid}: actual fit review/revision is missing')
            v.check(isinstance(fit.get('resolved_transform'), dict) and bool(fit.get('resolved_transform')),
                    f'{aid}: resolved transform is missing')
            v.check(fit.get('applied_once') is True, f'{aid}: applied-once contract is not recorded')
            qa = a.get('qa', {})
            required = ['technical', 'assembly_visual', 'save_reload']
            if a.get('category') in ('linen', 'padded', 'mail'): required.append('wear_opening')
            if a.get('category') == 'headgear': required.append('headgear_opening')
            if a.get('category') in ('sword', 'spear', 'bow', 'shield'): required.append('motion')
            if gate == 'game': required.append('game_consistency')
            for field in required: v.check(qa.get(field) == 'PASS', f'{aid}: {field} has not passed')
            v.evidence(qa.get('evidence'), f'{aid}.qa.evidence')
            if a.get('category') == 'headgear':
                hp = a.get('headgear_policy', {})
                for field in ('opaque_regions', 'layer_plan', 'hair_policy', 'beard_policy', 'bandage_policy', 'collar_interaction'):
                    val = hp.get(field)
                    v.check(val not in (None, '', 'unresolved') and val != [], f'{aid}: headgear {field} unresolved')
                v.check(hp.get('support_status') == 'VERIFIED', f'{aid}: headgear support is not verified')
        for preset in presets:
            pid = preset['preset_id']
            v.file(preset.get('resolved_package'), f'{pid}.resolved_package')
            v.check(bool(preset.get('assembly_revision')), f'{pid}: missing assembly revision')
            v.check(preset.get('save_reload') == 'PASS', f'{pid}: save/reload not passed')
            if gate == 'game': v.check(preset.get('game_consistency') == 'PASS', f'{pid}: game consistency not passed')
            v.evidence(preset.get('evidence'), f'{pid}.evidence')
        for c in cases:
            if c.get('gate') == 'game' and gate != 'game': continue
            cid = c['case_id']
            allowed = {'PASS'} if c.get('family') == 'pipeline' else {'PASS', 'NOT_APPLICABLE'}
            v.check(c.get('status') in allowed, f'{cid}: required check is not complete')
            if c.get('status') == 'PASS': v.evidence(c.get('evidence'), f'{cid}.evidence')

    summary = {
        'logical_assets': len(assets), 'designs': len(set(designs)),
        'headgear_designs': len(hg_designs), 'pilot_assets': sum(a.get('phase') == 'pilot' for a in assets),
        'presets': len(presets), 'preset_covered_assets': len(coverage),
        'qa_cases': len(cases), 'asset_statuses': dict(Counter(a.get('status') for a in assets)),
        'test_statuses': dict(Counter(c.get('status') for c in cases)),
    }
    return v, summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('batch_dir', nargs='?', default='.', type=Path)
    parser.add_argument('--gate', choices=['plan', 'assembled', 'game'], default='plan')
    parser.add_argument('--project-root', type=Path, help='Repository root for recorded relative file paths')
    args = parser.parse_args()
    if args.gate != 'plan' and args.project_root is None:
        parser.error('--project-root is required for assembled/game gates')
    try:
        v, summary = validate(args.batch_dir, args.gate, args.project_root)
    except (OSError, ValueError, TypeError, KeyError, AttributeError) as error:
        print(f'FAIL: cannot validate malformed or unreadable input: {error}', file=sys.stderr)
        return 1
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    if v.errors:
        print(f'FAIL: {len(v.errors)} error(s) at gate={args.gate}', file=sys.stderr)
        for error in v.errors[:40]: print(' - '+error, file=sys.stderr)
        if len(v.errors) > 40: print(f' ... {len(v.errors)-40} more errors omitted', file=sys.stderr)
        return 1
    print(f'PASS: static {args.gate} gate only. No images were generated or visually approved; Godot was not run.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
