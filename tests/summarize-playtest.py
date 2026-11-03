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
parser.add_argument('logs', nargs='+', type=Path)
args = parser.parse_args()
lines = []
for path in args.logs:
    for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
        match = re.match(r'^(\d{4}-\d{2}-\d{2}T[^,]+),.*\[FLog::Creator(?:Output|Warning|Error)\] (?:Warning: )?(M8 .*|M7 PASS .*|M7 CLIENT .*|M7 STUDIO FAIL.*)$', line)
        if match:
            lines.append(match.group(1) + ' ' + match.group(2))
lines.sort()
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')
summary = {'complete': any('M8 STUDIO SUITE PASS:' in s for s in lines),
           'failures': [s for s in lines if 'STUDIO FAIL' in s],
           # The final marker is emitted only after the 15-client round, natural
           # reset and post-reset client reports; it is that cohort's completion.
           'rounds': [s for s in lines if 'FULL ROUND PASS' in s or 'M8 STUDIO SUITE PASS:' in s],
           'routes': [s for s in lines if 'M8 ROUTE ' in s],
           'clientSamples': []}
for line in lines:
    if 'M8 CLIENT METRICS ' in line:
        head, data = line.split('{', 1)
        summary['clientSamples'].append({'label': head.strip(), 'metrics': json.loads('{' + data)})
args.output.with_suffix('.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
print(f"Selected {len(lines)} project lines; complete={summary['complete']}, failures={len(summary['failures'])}, fullRounds={len(summary['rounds'])}")
