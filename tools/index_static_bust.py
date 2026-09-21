"""Read alpha/geometry and write a catalog. Never changes any source pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'game/assets/art/static-bust'
# Artist-selected isolated regions. Width is the fitting specification, not an
# automatic fit to arbitrary visible edges. Each part uses uniform scaling.
PARTS = {
    'head': ('body-head', [68, 40, 477, 516], 34.0, [1, -28]),
    'wounded': ('body-head', [682, 655, 477, 516], 34.0, [1, -28]),
    'body': ('full-garments', [110, 78, 470, 546], 71.0, [1.5, -42]),
    'linen': ('full-garments-nested', [726, 78, 478, 546], 72.0, [1.5, -42]),
    'base': ('anatomy', [17, 918, 643, 260], 64.0, [0, 0]),
    'padded': ('full-garments-nested', [105, 644, 496, 557], 72.5, [1.5, -42]),
    'padded_damaged': ('full-damaged-nested', [105, 644, 496, 557], 72.5, [1.5, -42]),
    'mail': ('full-garments-nested', [731, 644, 497, 560], 72.5, [1.5, -42]),
    'mail_damaged': ('full-damaged-nested', [731, 644, 497, 560], 72.5, [1.5, -42]),
    'sword': ('weapons', [141, 75, 185, 596], 22.5, [0, 0]),
    'spear': ('weapons', [600, 42, 55, 630], 8.4, [0, 0]),
    'bow': ('weapons', [990, 87, 134, 580], 17.5, [0, 0]),
    'shield': ('weapons', [81, 737, 305, 455], 32.0, [28, 2]),
    'arrow': ('weapons', [591, 730, 75, 460], 4.0, [0, 0]),
    'impact': ('weapons', [883, 812, 313, 297], 20.0, [0, 0]),
}

catalog = {'schema': 1, 'style': 'H-static-bust', 'revision': 'U50-nested-wear',
           # Same anchors, scale and source registration as v3. Only artwork changed.
           'compatible_draft_baselines': [],
           # Measured in the base's own source rectangle, not screen coordinates.
           # Inner top-disc edge: source absolute center (338,1005), radii (289,72).
           'base_surface_pixels': {'center': [321, 87], 'radius': [289, 72]},
           'bust_alignment_shift': [2.0, 0.0], 'parts': {}}
report = {}
for name, (atlas, rect, width, position) in PARTS.items():
    path = DEST / (atlas + '.png')
    im = Image.open(path)
    assert im.mode == 'RGBA', path
    x, y, w, h = rect
    assert 0 <= x < x+w <= im.width and 0 <= y < y+h <= im.height, name
    alpha = im.getchannel('A').crop((x, y, x+w, y+h))
    assert alpha.getextrema() == (0, 255), name
    catalog['parts'][name] = {
        'atlas': 'res://assets/art/static-bust/' + path.name,
        'rect': rect, 'size': [width, round(width*h/w, 5)],
        'position': position, 'pivot': [0.5, 1.0],
    }
    report[name] = {'rect': rect, 'source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                    'alpha_extrema': alpha.getextrema(), 'size': im.size}
catalog['parts']['sword']['pivot'] = [0.5, 0.82]
catalog['parts']['spear']['pivot'] = [0.5, 0.70]
catalog['parts']['bow']['pivot'] = [0.8, 0.51]
catalog['parts']['arrow']['pivot'] = [0.5, 0.0]
catalog['parts']['impact']['pivot'] = [0.5, 0.5]
for name in ['body', 'linen', 'padded', 'padded_damaged', 'mail', 'mail_damaged']:
    catalog['parts'][name]['pivot'] = [0.5, 0.0]
for name in ['body', 'linen', 'padded', 'padded_damaged', 'mail', 'mail_damaged', 'head', 'wounded']:
    catalog['parts'][name]['position'][0] += catalog['bust_alignment_shift'][0]
# The clothing cutoff is the actual base top disc's FRONT half-ellipse. Moving
# the bust changes texture registration only; the disc/cutoff do not move.
base = catalog['parts']['base']
surface = catalog['base_surface_pixels']
scale = base['size'][0] / base['rect'][2]
catalog['bust_crop'] = {
    'center': [round(base['position'][i] + (surface['center'][i] - base['rect'][i+2]*base['pivot'][i])*scale, 6) for i in range(2)],
    'radius': [round(r*scale, 6) for r in surface['radius']], 'top': -120.0,
}
v3_path = DEST / 'catalog-v3.json'
v3 = json.loads(v3_path.read_text(encoding='utf-8'))
same_geometry = catalog['bust_crop'] == v3['bust_crop'] and all(
    catalog['parts'][name][field] == v3['parts'][name][field]
    for name in catalog['parts'] for field in ['rect', 'size', 'position', 'pivot'])
if same_geometry:
    # U49 could be saved locally with CRLF; Git checks out LF on all machines.
    legacy_text = v3_path.read_text(encoding='utf-8')
    catalog['compatible_draft_baselines'] = sorted({
        hashlib.sha256(legacy_text.encode('utf-8')).hexdigest(),
        hashlib.sha256(legacy_text.replace('\n', '\r\n').encode('utf-8')).hexdigest()})
(DEST / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')
(ROOT / 'art/validation/2026-09-21-nested-wear/metadata.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8', newline='\n')
print('Indexed 15 painted parts; alpha checked; no image pixels changed.')
