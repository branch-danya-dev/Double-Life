"""Catch undefined runtime names without pretending to type-check the Roblox API."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
engine_globals = {
    'game', 'workspace', 'script', 'Instance', 'Enum', 'task', 'warn',
    'CFrame', 'Color3', 'Random', 'RaycastParams', 'TweenInfo', 'UDim2', 'Vector2', 'Vector3',
}
result = subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau-analyze',
                         *[str(p.relative_to(root)) for p in sorted((root / 'src').rglob('*.luau'))]],
                        cwd=root, capture_output=True, text=True, encoding='utf-8')
unknown = set(re.findall(r"Unknown global '([^']+)'", result.stdout + result.stderr))
assert result.returncode in (0, 1), result.stderr
assert not (unknown - engine_globals), f'Undefined runtime globals: {sorted(unknown - engine_globals)}'
print('PASS: runtime scripts contain no undefined names outside explicit Roblox globals')
