"""Assert the shipping Rojo artifact includes services, but excludes test drivers."""
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
items = list(root.iter('Item'))
names = {item.findtext('Properties/string[@name="Name"]') for item in items}
required = {'Main', 'Game', 'Roles', 'World', 'Dossier', 'Interactions', 'GuardService',
            'GuardPolicy', 'NpcMover', 'Requests', 'RequestLedger', 'WorldEvents', 'Hud', 'Config'}
assert required <= names, required - names
assert not {'M1Tests', 'M1TestDriver', 'M1ClientAudit', 'Runner', 'Playthrough'} & names
server = next(i for i in items if i.get('class') == 'ServerScriptService')
server_names = {i.findtext('Properties/string[@name="Name"]') for i in server.iter('Item')}
assert required - {'Hud', 'Config'} <= server_names
print('PASS: shipping artifact contains all services, keeps server modules private, excludes test fixtures')
