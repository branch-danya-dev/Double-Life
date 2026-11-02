"""Assert the shipping Rojo artifact includes services, but excludes test drivers."""
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
items = list(root.iter('Item'))
names = {item.findtext('Properties/string[@name="Name"]') for item in items}
required = {'Main', 'Game', 'Roles', 'World', 'Dossier', 'Interactions', 'GuardService',
            'GuardPolicy', 'NpcMover', 'Requests', 'RequestLedger', 'WorldEvents', 'Hud', 'Config',
            'RoundPolicy', 'RoundService', 'RolePlan', 'SessionClock', 'Evidence',
            'EventDirector', 'EventPolicy', 'PracticePolicy', 'EventWorld'}
assert required <= names, required - names
assert not {'M1Tests', 'M1TestDriver', 'M1ClientAudit', 'M2Tests', 'M2TestDriver', 'M2ClientAudit', 'M3Tests', 'M3TestDriver', 'M3ClientAudit', 'Runner', 'Playthrough'} & names
server = next(i for i in items if i.get('class') == 'ServerScriptService')
server_names = {i.findtext('Properties/string[@name="Name"]') for i in server.iter('Item')}
assert required - {'Hud', 'Config'} <= server_names
sources = '\n'.join(i.findtext('Properties/*[@name="Source"]') or '' for i in items)
assert 'M2TestDriver' not in sources and 'M1TestDriver' not in sources
assert 'M3TestDriver' not in sources
assert 'task.delay(' not in sources, 'gameplay delays must be cancellable round-local timers'
assert 'Config.ROUND_SECONDS = 420' in sources
assert 'Config.EVENT_COOLDOWN = 55' in sources and 'Config.EVENT_LIMIT = 2' in sources
print('PASS: shipping artifact contains all services, keeps server modules private, excludes test fixtures')
