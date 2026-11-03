"""Chat must be configured before engine scripts load, in every project and artifact."""
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

CONFIGS = ['ChatWindowConfiguration', 'ChatInputBarConfiguration', 'BubbleChatConfiguration', 'ChannelTabsConfiguration']
for path in Path('.').glob('*.project.json'):
    tree = json.loads(path.read_text(encoding='utf-8'))['tree']
    assert tree['Chat']['$properties']['LoadDefaultChat'] is False, path
    chat = tree['TextChatService']
    assert chat['$properties'] == {'ChatVersion': 'TextChatService', 'CreateDefaultTextChannels': False, 'CreateDefaultCommands': False}, path
    for name in CONFIGS:
        assert chat[name]['$className'] == name and chat[name]['$properties']['Enabled'] is False, (path, name)
for path in sys.argv[1:]:
    root = ET.parse(path).getroot()
    for cls, props in {'Chat': {'LoadDefaultChat': 'false'}, 'TextChatService': {'ChatVersion': '1', 'CreateDefaultTextChannels': 'false', 'CreateDefaultCommands': 'false'}, **{n: {'Enabled': 'false'} for n in CONFIGS}}.items():
        items = [i for i in root.iter('Item') if i.get('class') == cls]
        assert len(items) == 1, (path, cls, 'must be unique')
        for key, value in props.items():
            assert items[0].findtext(f'Properties/*[@name="{key}"]') == value, (path, cls, key)
print('PASS: all project definitions and supplied artifacts disable legacy loading, channels, commands and four chat surfaces')
