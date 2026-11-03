"""Prevent a second Main from winning the fixture's memory-adapter startup race."""
import sys
import xml.etree.ElementTree as ET

for path in sys.argv[1:]:
    root = ET.parse(path).getroot()
    server = next(i for i in root.iter('Item')
                  if i.findtext('Properties/string[@name="Name"]') == 'DoubleLifeServer')
    children = server.findall('Item')
    names = [i.findtext('Properties/string[@name="Name"]') for i in children]
    assert len(names) == len(set(names)), f'{path}: duplicate server modules/entry points'
    main = next(i for i in children if i.findtext('Properties/string[@name="Name"]') == 'Main')
    source = main.findtext('Properties/*[@name="Source"]') or ''
    assert 'M7_TEST_INACTIVE_MAIN' in source and 'require(' not in source, path
    assert main.findtext('Properties/bool[@name="Disabled"]') == 'true', path
    runners = [i for i in root.iter('Item') if i.findtext('Properties/string[@name="Name"]') == 'Runner']
    assert len(runners) == 1 and 'MemoryStore' in runners[0].findtext('Properties/*[@name="Source"]'), path
    print(f'PASS: {path}: unique inert Main; fixture Runner owns isolated-memory startup')
