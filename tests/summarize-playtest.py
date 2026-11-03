"""Export only project-authored M8 evidence, never raw Studio/network/account logs.

Usage: python tests/summarize-playtest.py --output docs/evidence/M8-studio.log LOG...
The input paths must be the explicitly selected logs from this test session.
"""
import argparse
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--staff-gate', action='store_true', help='Expect the focused M8.1 positive + negative rounds')
parser.add_argument('--stage', default='M8', help='Project fixture prefix, e.g. M9')
parser.add_argument('logs', nargs='+', type=Path)
args = parser.parse_args()
assert re.fullmatch(r'M\d+', args.stage), 'Invalid stage prefix'
lines = []
for path in args.logs:
    for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
        match = re.match(r'^(\d{4}-\d{2}-\d{2}T[^,]+),.*\[FLog::Creator(?:Output|Warning|Error)\] (?:Warning: )?('
                         + re.escape(args.stage) + r' .*|M8 .*|M7 PASS .*|M7 CLIENT .*|M7 STUDIO FAIL.*)$', line)
        if match:
            lines.append(match.group(1) + ' ' + match.group(2))
lines.sort()
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')
completion = 'M8 STAFF DELIVERY GATE PASS:' if args.staff_gate else args.stage + ' STUDIO SUITE PASS:'
summary = {'complete': any(completion in s for s in lines),
           'failures': [s for s in lines if 'STUDIO FAIL' in s],
           # The final marker follows the last cohort's natural reset and client
           # reports (15 in full M8; the negative 5-client round in staff mode).
           'rounds': [s for s in lines if 'FULL ROUND PASS' in s or completion in s],
           'routes': [s for s in lines if 'M8 ROUTE ' in s or args.stage + ' ROUTE ' in s],
           'clientSamples': []}
for line in lines:
    if 'M8 CLIENT METRICS ' in line:
        head, data = line.split('{', 1)
        summary['clientSamples'].append({'label': head.strip(), 'metrics': json.loads('{' + data)})
args.output.with_suffix('.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
print(f"Selected {len(lines)} project lines; complete={summary['complete']}, failures={len(summary['failures'])}, fullRounds={len(summary['rounds'])}")
