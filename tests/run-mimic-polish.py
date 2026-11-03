"""Execute actual identity admission and local crowd navigation with bounded adapters."""
from pathlib import Path
import argparse, subprocess, tempfile
p=argparse.ArgumentParser(description=__doc__); p.add_argument('--luau',default='luau'); a=p.parse_args()
root=Path(__file__).resolve().parents[1]
sources={name:(root/f'src/server/{name}.luau').read_text(encoding='utf-8') for name in ['MimicIdentity','MimicCrowd','RoundService','NpcMover']}
wrapper='local sources={}\n'+''.join(f'sources.{name}=[====[{source}]====]\n' for name,source in sources.items())
wrapper+='''require('./mimic-polish-runtime').run(function(name,modules,extra)
    local env=setmetatable(extra or {},{__index=getfenv()})
    env.script={Parent=setmetatable({},{__index=function(_,k) return k end})}
    env.require=function(k) return assert(modules[k],k) end
    local chunk=assert(loadstring(sources[name],name)); setfenv(chunk,env); return chunk()
end)
'''
with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',suffix='.luau',prefix='m112-harness-',dir=root/'tests',delete=False) as f:
    f.write(wrapper); temp=Path(f.name)
try: result=subprocess.run([a.luau,str(temp)],cwd=root)
finally: temp.unlink()
raise SystemExit(result.returncode)
