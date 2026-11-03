"""Audit participant payloads, bounded admission, cleanup and isolation."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
read=lambda p:(r/p).read_text(encoding='utf-8')
sources='\n'.join(p.read_text(encoding='utf-8') for p in (r/'src').rglob('*.luau'))
assert '· персонаж' not in read('src/server/MimicRig.luau')+read('src/server/RoundService.luau')
assert 'name=actor.name}' in read('src/server/RoundService.luau')
service=read('src/server/MimicService.luau'); rig=read('src/server/MimicRig.luau')
assert service.index('used[preset]=true')<service.index('pcall(Rig.new')
assert service.index('self.names[nickname]=true')<service.index('pcall(Rig.new')
assert 'self.names[a.actor.name]=nil' in service and 'self.crowd:release(mover)' in service
assert rig.count('(admit and not admit())')==2 and 'label.Text=name' in rig
assert 'GetAppliedDescription()' in service and 'GetHumanoidDescriptionFromUserId' not in service
assert 'local players=Players:GetPlayers()' in service and service.count('self.crowd:update(')==1
assert 'self.busy>=settings.aiWorkers' in service
for path in ['MimicIdentity','MimicCrowd','MimicCrowdPolicy']:
    code=read('src/server/'+path+'.luau')
    for forbidden in ['DataStore','Marketplace','TeleportService','InvokeClient','UserId=']:
        assert forbidden not in code
assert 'doubleLifeFakePlayer' not in sources
print('PASS: names/payloads, pre-yield reservations, bounded navigation, cleanup and isolation')
