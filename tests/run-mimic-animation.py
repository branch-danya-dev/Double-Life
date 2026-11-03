"""Run the actual server animation controller against deterministic engine adapters."""
from pathlib import Path
import argparse
import subprocess
import tempfile
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--luau',default='luau')
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/MimicAnimation.luau').read_text(encoding='utf-8')
assert ']====]' not in source
wrapper='''local suite=require("./mimic-animation-runtime")
local source=[====[%s]====]
suite.run(function(env)
    local chunk=assert(loadstring(source,"MimicAnimation")); setfenv(chunk,env); return chunk()
end)
''' % source
with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',suffix='.luau',prefix='mimic-harness-',dir=root/'tests',delete=False) as f:
    f.write(wrapper); temporary=Path(f.name)
try:
    result=subprocess.run([a.luau,str(temporary)],cwd=root)
finally:
    temporary.unlink()
raise SystemExit(result.returncode)
