"""Fetch only the Windows export entries from the official Godot template ZIP."""
import io, json, pathlib, struct, urllib.request, zipfile
ROOT = pathlib.Path(__file__).resolve().parent.parent
URL = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
class RemoteZip(io.RawIOBase):
    def __init__(self):
        req = urllib.request.Request(URL, method="HEAD", headers={"User-Agent":"FantasyBrothers-build"})
        with urllib.request.urlopen(req, timeout=60) as response:
            self.url=response.geturl()
            self.length=int(response.headers["Content-Length"])
        self.pos=0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence==0 else self.pos+offset if whence==1 else self.length+offset
        return self.pos
    def read(self, size=-1):
        if size<0: size=self.length-self.pos
        size=min(size,self.length-self.pos)
        if size<=0: return b""
        if size>150_000_000: raise RuntimeError("Unexpected oversized entry")
        req=urllib.request.Request(self.url,headers={"Range":f"bytes={self.pos}-{self.pos+size-1}","User-Agent":"FantasyBrothers-build"})
        with urllib.request.urlopen(req,timeout=120) as response:
            if response.status!=206: raise RuntimeError(f"Range request returned {response.status}")
            data=response.read(size)
        if len(data)!=size: raise RuntimeError("Incomplete range")
        self.pos+=len(data)
        return data
out=ROOT/"tools"/"templates"/"4.7.2"
out.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(RemoteZip()) as archive:
    selected=[i for i in archive.infolist() if pathlib.PurePosixPath(i.filename).name in {"windows_release_x86_64.exe","windows_debug_x86_64.exe"}]
    if len(selected)!=2: raise RuntimeError("Expected Windows template pair missing")
    for info in selected:
        path=out/pathlib.PurePosixPath(info.filename).name
        print(f"Extracting {path.name} ({info.compress_size} compressed bytes)",flush=True)
        path.write_bytes(archive.read(info))
        print(f"CRC verified: {path.name}",flush=True)
(out/"source.json").write_text(json.dumps({"url":URL,"version":"4.7.2-stable","files":[p.name for p in out.glob("*.exe")]},indent=2),encoding="utf-8")
