"""Verify the authored M7 source package against its provenance receipt."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'assets/M7-manifest.json').read_text(encoding='utf-8'))
assert manifest['schema'] == 1
for asset in manifest['authoredSources']:
    path = (root / asset['path']).resolve()
    assert path.is_relative_to(root) and path.suffix == '.luau'
    assert asset['rights'] == 'Project-original; no public license grant'
    assert asset['normalization'] == 'UTF-8 LF'
    assert hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest() == asset['sha256'], asset['path']
assert manifest['externalDownloads'] == [] and manifest['paidProviderJobs'] == []
assert {s['uri'] for s in manifest['engineAudio']} == {
    'rbxasset://sounds/action_jump_land.mp3', 'rbxasset://sounds/action_swim.mp3'}
for asset in manifest['engineAudio']:
    assert asset['distribution'] == 'Runtime reference only; no copied binary'
print('PASS: M7 authored source hashes, provenance, engine-only audio and zero external downloads')
