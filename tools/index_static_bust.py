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
    'head': ('body-head', [68, 40, 477, 516], 51.0, [3, -34]),
    'wounded': ('body-head', [682, 655, 477, 516], 51.0, [3, -34]),
    'body': ('body-head', [584, 282, 660, 369], 74.0, [0, -10]),
    'linen': ('anatomy', [584, 203, 670, 360], 76.0, [0, -10]),
    'base': ('anatomy', [17, 918, 643, 260], 75.0, [0, 0]),
    'padded': ('armor', [56, 219, 542, 302], 78.0, [0, -10]),
    'padded_damaged': ('armor', [656, 219, 542, 302], 78.0, [0, -10]),
    'mail': ('armor', [61, 763, 540, 303], 79.0, [0, -10]),
    'mail_damaged': ('armor', [656, 767, 540, 303], 79.0, [0, -10]),
    'sword': ('weapons', [141, 75, 185, 596], 19.0, [0, 0]),
    'spear': ('weapons', [600, 42, 55, 630], 7.0, [0, 0]),
    'bow': ('weapons', [990, 87, 134, 580], 14.0, [0, 0]),
    'shield': ('weapons', [81, 737, 305, 455], 30.0, [24, -4]),
    'arrow': ('weapons', [591, 730, 75, 460], 3.4, [0, 0]),
    'impact': ('weapons', [883, 812, 313, 297], 20.0, [0, 0]),
}

catalog = {'schema': 1, 'style': 'H-static-bust', 'parts': {}}
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
(DEST / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
(ROOT / 'art/validation/2026-09-20-static-bust/metadata.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print('Indexed 15 painted parts; alpha checked; no image pixels changed.')
