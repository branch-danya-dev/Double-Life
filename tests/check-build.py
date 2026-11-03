"""Assert the shipping Rojo artifact includes services, but excludes test drivers."""
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
items = list(root.iter('Item'))
names = {item.findtext('Properties/string[@name="Name"]') for item in items}
required = {'Main', 'Game', 'Roles', 'World', 'Dossier', 'Interactions', 'GuardService',
            'GuardPolicy', 'NpcMover', 'Requests', 'RequestLedger', 'WorldEvents', 'Hud', 'Config',
            'RoundPolicy', 'RoundService', 'RolePlan', 'SessionClock', 'Evidence',
            'EventDirector', 'EventPolicy', 'PracticePolicy', 'EventWorld',
            'ProfileService', 'ProfileSchema', 'ProgressionPolicy', 'ProfileStore', 'ProfileSessions',
            'ProgressionCatalog', 'DataStoreAdapter', 'PersistenceSettings', 'SocialHud',
            'SocialService', 'SocialPolicy', 'CommerceService', 'CommerceStore', 'CommercePolicy',
            'CommerceCatalog', 'MonetizationSettings', 'MarketplaceAdapter', 'Telemetry', 'AnalyticsPolicy',
            'MansionLayout', 'WorldContract', 'MansionArt', 'MansionArtPlan', 'Presentation', 'Atmosphere', 'Interface'}
assert required <= names, required - names
assert not {'M1Tests', 'M1TestDriver', 'M1ClientAudit', 'M2Tests', 'M2TestDriver', 'M2ClientAudit', 'M3Tests', 'M3TestDriver', 'M3ClientAudit', 'Runner', 'Playthrough'} & names
assert not {'M4Tests', 'M4TestDriver', 'M4ClientAudit', 'MemoryStore'} & names
assert not {'M41Tests', 'M41TestDriver', 'M41ClientAudit'} & names
assert not {'M5Tests', 'M5TestDriver', 'M5ClientAudit', 'FakeMarketplace'} & names
assert not {'M6Tests', 'M6TestDriver', 'M6ClientAudit'} & names
assert not {'M7Audit', 'M7ClientAudit', 'M7ReviewTests', 'M7ReviewClient', 'M7Review'} & names
assert not {'M8Tests', 'M8ClientAudit', 'M8Metrics', 'M8AuditDriver'} & names
assert not {'M9Tests', 'M9TestDriver'} & names
assert not {'M10Tests', 'M10TestDriver'} & names
assert not {'M11Tests', 'TelemetrySink'} & names
assert not {'M112Tests', 'M112Context'} & names
assert {'MimicIdentity', 'MimicCrowdPolicy', 'MimicCrowd', 'MimicNames'} <= names
assert not {'M111Tests', 'M111Review', 'M111Context', 'BeforeM11Rig'} & names
assert {'MimicAppearance', 'MimicLoadPolicy', 'MimicAnimation', 'MimicPresentation'} <= names
assert {'RetentionPolicy', 'TuningConfig'} <= names
assert {'PrologueService', 'ProloguePolicy', 'PrologueContent', 'PrologueWorld', 'PrologueHud'} <= names
assert {'ActorRegistry', 'ActorPolicy', 'Matchmaking', 'MatchPool', 'MatchTransport', 'QueuePolicy', 'LobbyWorld', 'MimicRig', 'MimicService', 'LobbyHud'} <= names
assert 'M8AuditDriver' not in '\n'.join(i.findtext('Properties/*[@name="Source"]') or '' for i in items)
assert {'ChatSetup', 'RoleGuide'} <= names
assert 'M7Review' not in '\n'.join(i.findtext('Properties/*[@name="Source"]') or '' for i in items)
assert 'M7_TEST_INACTIVE_MAIN' not in '\n'.join(i.findtext('Properties/*[@name="Source"]') or '' for i in items)
server = next(i for i in items if i.get('class') == 'ServerScriptService')
server_names = {i.findtext('Properties/string[@name="Name"]') for i in server.iter('Item')}
assert required - {'Hud', 'SocialHud', 'Config', 'Presentation', 'Atmosphere', 'Interface'} <= server_names
sources = '\n'.join(i.findtext('Properties/*[@name="Source"]') or '' for i in items)
assert 'M112ContextView' not in sources
assert 'M111Review' not in sources and 'M111ContextView' not in sources
assert 'M2TestDriver' not in sources and 'M1TestDriver' not in sources
assert 'M3TestDriver' not in sources
assert 'M4TestDriver' not in sources
assert 'M5TestDriver' not in sources and 'FakeMarketplace' not in names
assert 'M6TestDriver' not in sources
assert sources.count('Marketplace.ProcessReceipt =') == 1
assert 'PromptProductPurchaseFinished' not in sources
assert 'enabled = false' in sources and 'isolatedDataStoreVerified = false' in sources
assert 'passId = 0' in sources and 'productId = 0' in sources
assert 'self.rt.roles' not in (next(i.findtext('Properties/*[@name="Source"]') for i in items if i.findtext('Properties/string[@name="Name"]') == 'CommerceService'))
assert 'M41TestDriver' not in sources
assert 'studioEnabled = false' in sources and 'studioUniverseId = 0' in sources
assert 'store:UpdateAsync(key, transform)' in sources and 'SetAsync(' not in sources
assert 'task.delay(' not in sources, 'gameplay delays must be cancellable round-local timers'
assert 'Config.ROUND_SECONDS = 1200' in sources
assert 'Config.EVENT_COOLDOWN = 55' in sources and 'Config.EVENT_LIMIT = 2' in sources
print('PASS: shipping artifact contains all services, keeps server modules private, excludes test fixtures')
