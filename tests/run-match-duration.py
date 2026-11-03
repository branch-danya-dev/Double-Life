"""Run the actual RoundService with only engine physics/Players adapted."""
from pathlib import Path
import argparse, subprocess, tempfile
p=argparse.ArgumentParser(description=__doc__); p.add_argument('--luau',default='luau'); a=p.parse_args()
root=Path(__file__).resolve().parents[1]
source=(root/'src/server/RoundService.luau').read_text(encoding='utf-8')
wrapper='local source=[====['+source+']====]\n'+'''require('./match-duration-runtime').run(function(modules,extra)
    local env=setmetatable(extra,{__index=getfenv()})
    env.script={Parent=setmetatable({},{__index=function(_,k) return k end})}
    env.require=function(k) return assert(modules[k],k) end
    local chunk=assert(loadstring(source,"RoundService")); setfenv(chunk,env); return chunk()
end)
'''
with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',suffix='.luau',prefix='m120-harness-',dir=root/'tests',delete=False) as f:
    f.write(wrapper); temp=Path(f.name)
try: result=subprocess.run([a.luau,str(temp)],cwd=root)
finally: temp.unlink()
raise SystemExit(result.returncode)
