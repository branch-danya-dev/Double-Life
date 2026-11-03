"""Run the real Requests module with deterministic engine adapters and real policies."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luau', default='luau')
parser.add_argument('--source', type=Path)
parser.add_argument('--reproduce', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
source = (args.source or root / 'src/server/Requests.luau').read_text(encoding='utf-8')
equals = '===='
while ']' + equals + ']' in source:
    equals += '='
wrapper = f'''local suite = require("./staff-delivery")
local source = [{equals}[{source}]{equals}]
suite.{"reproduce" if args.reproduce else "run"}(function(environment)
    local chunk = assert(loadstring(source, "Requests"))
    setfenv(chunk, environment)
    return chunk()
end)
'''
with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', suffix='.luau',
                                 prefix='staff-harness-', dir=root / 'tests', delete=False) as f:
    f.write(wrapper)
    temporary = Path(f.name)
try:
    result = subprocess.run([args.luau, str(temporary)], cwd=root)
finally:
    temporary.unlink()
raise SystemExit(result.returncode)
