"""Package actual renderer screenshots unchanged; index provenance and alpha.

No sprite painting, raster editing, masking, resizing or PNG re-encoding occurs.
"""
from pathlib import Path
import argparse, hashlib, json, shutil
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/production/2026-09-20-a-standard'
ASSETS=ROOT/'game/assets/art/a-standard'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser();p.add_argument('capture_dir',type=Path);args=p.parse_args()
    errors=args.capture_dir/'errors.log'
    if errors.exists() and errors.read_text(encoding='utf-8-sig').strip():
        raise RuntimeError('Renderer reported errors; do not package this run')
    frames=sorted(args.capture_dir.glob('*.png'))
    if len(frames)!=345:raise RuntimeError(f'Expected 345 complete real-renderer captures, got {len(frames)}')
    (OUT/'previews').mkdir(exist_ok=True)
    for path in frames:shutil.copy2(path,OUT/'previews'/path.name)
    files=[]
    for path in sorted((OUT/'sources').glob('*.png')):
        with Image.open(path) as im:
            if im.mode!='RGBA':raise RuntimeError(f'Missing alpha: {path}')
            alpha=im.getchannel('A');hist=alpha.histogram()
            if hist[0]==0 or sum(hist[128:])==0:raise RuntimeError(f'Bad transparent cutout: {path}')
            files.append(dict(file='sources/'+path.name,sha256=digest(path),width=im.width,height=im.height,alpha_extrema=alpha.getextrema(),transparent_pixels=hist[0],bytes=path.stat().st_size))
    runtime=[]
    source_hashes={f['sha256'] for f in files}
    for path in sorted(ASSETS.glob('*.png')):
        sha=digest(path)
        if sha not in source_hashes:raise RuntimeError(f'Runtime texture not an unmodified source: {path}')
        runtime.append(dict(file=str(path.relative_to(ROOT)).replace('\\','/'),sha256=sha))
    manifest=dict(schema=1,tool='OpenAI built-in image_gen',model='not reported by tool',operator='main agent; no subagents',source_images=files,runtime_images=runtime,captures=dict(count=len(frames),source=str(args.capture_dir.resolve()),files=[dict(file=x.name,sha256=digest(x)) for x in frames]),licensing='Original generated artwork for this project; reference style is not a third-party asset license. No Battle Brothers pixels in runtime resources.')
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Packaged {len(files)} original PNGs, {len(runtime)} unmodified runtime textures and {len(frames)} exported-renderer captures.')

if __name__=='__main__':main()
