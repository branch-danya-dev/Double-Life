# M11.1 — R15-мимики

База: M11 `c672e96457d15d92aa1c6d1fa10db8de7ccd5bf4`, Issue #27.

## Внешность

`MimicAppearance` содержит 20 вымышленных персонажей: 10 повседневных,
6 smart-casual и 4 выразительных (50/30/20 по полному каталогу).
Небольшая группа не обязана математически повторять эти доли. Seed `271828`
задаёт воспроизводимую перестановку; занятый вариант резервируется **до**
асинхронной загрузки. В пределах каждого Lobby/Match/private scene дублей нет.
У уже созданного Actor не меняются имя, модель, одежда или пропорции.

Используются Classic, Man и Woman R15, три стандартных варианта лица/головы,
шесть оттенков кожи, разные масштабы и сочетания одежды. Smart-casual здесь —
рубашки и аккуратные куртки; каталог ограничен проверенным бесплатным набором
Roblox и не содержит отдельной коллекции платьев или платного UGC. Яркие волосы
и оранжевая шапка дают выразительные образы без единой униформы.

`HumanoidDescription` + `CreateHumanoidModelFromDescriptionAsync` создают всё
тело, одежду и аксессуары. Самодельные глаза, улыбка, волосы и жилет удалены.
Проверка допуска требует R15, 15 частей тела, root, 15 соединённых суставов,
одежду и совпадающие ID применённых аксессуаров. Поддержаны Motor6D и новые
AnimationConstraint: Roblox использует последние при Avatar Joint Upgrade.
Для layered hair проверяется `GetAccessories(true)`, поскольку после сборки
поле `HairAccessory` может быть пустым.

## Загрузка и отказы

- Не более 20 описаний и 20 завершённых шаблонов на сервер; внешность не
  запрашивается по аккаунтам игроков. Шаблоны не находятся в Workspace.
- Один незавершённый запрос Avatar API на сервер, общий для всех контекстов.
  Допуск ждёт максимум 8 секунд. Просроченный запрос продолжает занимать слот
  до реального завершения: тайм-аут не запускает новые запросы за его спиной.
- Повтор после ошибок ограничен паузами 2/4/8/16 секунд; успешные запросы также
  имеют минимальный интервал. MimicService создаёт не чаще одного актёра за
  2 секунды и обслуживает private scenes через общую очередь.
- Холодный отказ откладывает появление. Тёплый отказ использует **тот же**
  проверенный R15-шаблон. `NpcMover.new` никогда не вызывается для мимиков.
  Поздний ответ может заполнить кеш, но не создаёт осиротевшего Actor.
- Перед видимостью сервер ждёт готовности шести треков (до 5 секунд).
  Недоступный жест/вариант Idle один раз заменяется штатной нейтральной Idle
  с дополнительным ожиданием до 2 секунд. Без готовых Walk/Run появление
  откладывается: скольжение неподвижного тела не допускается.
  Клиент отдельно ждёт полный набор частей и загрузку локальных текстур/мешей,
  затем плавно показывает модель за 0,35 секунды. На клиенте максимум два
  незавершённых preload, до трёх попыток; при постоянном отказе модель остаётся
  скрытой, а не появляется частично. Зависший preload удерживает слот.
- Отмена private scene, reset и despawn освобождают актёра, резерв внешности,
  треки и наблюдателей. Кеш шаблонов остаётся ограниченным каталогом.

## Анимации и поведение

На каждом NPC сервер создаёт Animator и один набор из шести AnimationTrack:
один из двух Idle, Walk, Run, Wave, Point, Cheer. Это стандартные R15-анимации
Roblox; загружаются один раз, а не на Heartbeat. Используются приоритеты
Idle/Movement/Action и переходы 0,2 секунды. Скорость Walk/Run зависит от
фактической горизонтальной скорости root; гистерезис предотвращает дрожание
между Idle и Walk. Council и музыкальная остановка замораживают треки.

Паузы 2,5–7,9 секунды и разные Idle не дают всем персонажам действовать
синхронно. Приветствие срабатывает рядом с человеком во время остановки,
с интервалом не меньше 18 секунд. AlignOrientation поворачивает всё тело;
постоянного слежения головой и ручных записей C0 нет. Жесты прекращаются
при движении. В Lobby отдельные места остановки вокруг каждого объекта разнесены на 3,5 stud; персонажи смотрят на объект, не занимая одну точку. Все прежние маршруты, Guest-действия и два path worker сохранены.

В Match точки появления разнесены на 3,5 stud по свободному полу буфета.
Прежнее смещение от Service.Home попадало внутрь стойки; регрессии проверяют
все 20 позиций относительно границ комнаты и мебели.

Owner/Spy остаются людьми. Мимики — отдельные `m:` Guest actors: не Roblox
Players, не владельцы профилей, покупок или наград. Подписи «персонаж», кворум,
отключённый чат и настройки DataStore/межсерверного транспорта не изменялись.

## Происхождение ассетов

Все 43 ID проверены в реальном Studio через `MarketplaceService:GetProductInfoAsync`
**только в тестовом Runner**. Автор — Roblox (`CreatorTargetId = 1`). Классическая
одежда и волосы имеют цену 0; части тела/головы входят в бесплатные пакеты
[Man](https://www.roblox.com/bundles/238/Man) и
[Woman](https://www.roblox.com/bundles/239/Woman), а треки — стандартные R15.
Метаданные сохранены в [M111-assets.json](evidence/M111-assets.json).
Бинарные ассеты не скачивались, не продавались и не переиздавались: используются
ID штатного avatar runtime Roblox. Это не заявление об отдельной лицензии
на распространение исходных моделей вне Roblox.

Типы/ID зафиксированы аудитом `tests/check-mimic-assets.py`. Изменение набора
требует новой проверки доступности, типа, автора, видимости и репликации.

Основные источники API: [внешность персонажей](https://create.roblox.com/docs/characters/appearance),
[Animator](https://create.roblox.com/docs/reference/engine/classes/Animator),
[AnimationConstraint](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint).

## Производительность и проверка

Числа фактического прогона, изображения и ограничения устройств приведены в
[M11_1_VALIDATION.md](M11_1_VALIDATION.md). Счётчики `Rig.metrics` различают
живые модели/треки, незавершённые API-запросы, отказы, отсрочки и кеш.
Это локальная проверка Studio, а не измерение физического мобильного устройства.

Причёска 62234425 исключена после проверки клиента: её вложенная текстура 81504106 возвращала AssetDelivery404. В двух пресетах используется проверенная 376548738.
## M11.2: выбор имени и образа, движение в толпе

The 20 approved R15 descriptions and their 50/30/20 mix remain unchanged. `MimicIdentity` checks new admissions against the **live** human Characters via `Humanoid:GetAppliedDescription()` and `HumanoidDescription:GetAccessories(true)`. No account lookups are made. Same shirt and pants plus either shared hair or the same body/head is treated as a near clone; tiny colour, face and scale differences do not rescue that candidate. A single shared garment is allowed. This conservative filter intentionally rejects more than exact byte equality.

The deterministic catalogue order is filtered before reserving a preset. The preset remains reserved through the asynchronous R15 load, and the live human appearance is checked again before parenting and before revealing the model. Exhaustion defers admission until the existing two-second creation interval. Loaded actors keep their appearance: a human who joins later or changes clothes can introduce a new resemblance; already-visible actors are never redressed. There is no guarantee against all perceptual similarity across arbitrary user-created accessories.

Fictional nicknames are reserved globally across the server's AI actors, compared with both actual account names and DisplayNames (case, separators and common Latin/Cyrillic lookalikes). At most 100 suffix variants are tried. Names stay fixed for actor lifetime and are shared by the model, nameplate and Council payload. The individual `· персонаж` suffix is removed. Truthful aggregate human/AI counts and the real Roblox player list remain unchanged. The client hides overlapping AI plates at 10 Hz, gives human plates priority and shows names only within 35 studs. This does not alter real account/profile/chat identity.

`MimicCrowd` snapshots at most 64 local human/AI roots at 10 Hz, including the existing guard and staff NPC. It excludes actors on different floors (four-stud vertical band). Each destination has at most 25 candidate standing positions within ten studs, checked for floor support, solid overlaps and 4.2-stud clearance from bodies and pending reservations. Reservations are released on completion, cancellation and despawn.

Only mimic movers opt into the new waypoint controller in `NpcMover`; guard/staff routing retains its existing behavior. It checks a six-stud segment, keeps a 3.2-stud body clearance, tries at most two lateral detours per waypoint and otherwise waits up to 1.4 seconds before yielding the route. Detours require clear static geometry and supported floor. Each waypoint is bounded by eight seconds and the existing 30-second job deadline; existing two path attempts, compute timeout and two AI workers remain. No rigid player-blocking colliders or movement teleports are introduced. A player can still deliberately enter an AI body; movement away from that overlap is allowed.

Reference APIs: [applied Humanoid description](https://create.roblox.com/docs/reference/engine/classes/Humanoid), [normalized accessories](https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription), [Roblox pathfinding](https://create.roblox.com/docs/characters/pathfinding). Validation and limitations are recorded separately in [M11.2 validation](M11_2_VALIDATION.md).
