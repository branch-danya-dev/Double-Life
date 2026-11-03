"""Keep production mimic assets inside the Studio-verified Roblox allowlist."""
from pathlib import Path
import json
import re
import hashlib
root=Path(__file__).resolve().parents[1]
catalog=(root/'src/server/MimicAppearance.luau').read_text(encoding='utf-8')
manifest=json.loads((root/'docs/evidence/M111-assets.json').read_text(encoding='utf-8-sig'))
assets={a['id']:a for a in manifest['assets']}
used={int(x) for x in re.findall(r'\b\d{8,}\b',catalog)}-{2147483647}
assert used==set(assets), (used-set(assets),set(assets)-used)
assert all(a['creator']==1 and a['type'] in {11,12,24,27,28,29,30,31,41,79} for a in assets.values())
assert all(a.get('price')==0 for a in assets.values() if a['type'] in {11,12,41})
for field,kind in [('Torso',27),('RightArm',28),('LeftArm',29),('LeftLeg',30),('RightLeg',31)]:
    for id_ in re.findall(field+r'=(\d+)',catalog): assert assets[int(id_)]['type']==kind
for id_ in re.findall(r'=(\d+)',catalog.split('A.animations=')[1].split('\n')[0]): assert assets[int(id_)]['type']==24
rig=(root/'src/server/MimicRig.luau').read_text(encoding='utf-8')
motion=(root/'src/server/MimicAnimation.luau').read_text(encoding='utf-8')
service=(root/'src/server/MimicService.luau').read_text(encoding='utf-8')
for forbidden in ['Mover.new(','.C0=', 'EveningWaistcoat', 'OriginalHair', 'HairBun', 'GetHumanoidDescriptionFromUserId', 'CreateHumanoidModelFromUserId', 'MarketplaceService', 'DataStoreService']:
    assert forbidden not in rig+motion+service, forbidden
assert 'CreateHumanoidModelFromDescriptionAsync' in rig and 'AnimationConstraint' in rig
assert 'animator:LoadAnimation' in motion and 'track:Destroy()' in motion
baseline=(root/'tests/m111/BeforeRig.luau').read_bytes().replace(b'\r\n',b'\n')
assert hashlib.sha256(baseline).hexdigest()=='166bcfcf32bb2f5fbef75c43aa6597c72dad1339eb2b3f71111c3977fc13369f', 'before evidence must use unmodified M11 source'
print(f'PASS: {len(assets)} Studio-verified Roblox assets; no account lookup, block fallback, or manual joints; authentic M11 baseline')
