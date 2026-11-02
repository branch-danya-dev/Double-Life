-- Server authority for prices, unlocks and tool parameters. No paid products in M4.
local Catalog = {}
Catalog.roles = {"Spy", "CounterAgent", "Owner", "Staff", "Guest"}
Catalog.defaults = {Spy = "Lockpick", CounterAgent = "Journal", Owner = "OwnerLedger", Staff = "ServingTray", Guest = "GuestGuide"}
Catalog.items = {
    Lockpick = {name = "Отмычка", slot = "Spy", level = 1, description = "Окно 14 с; след на раме 35 с. Удержание 5 с.", window = 14, trace = 35},
    Prybar = {name = "Рычажный инструмент", slot = "Spy", level = 2, description = "Окно 22 с, но заметный след остаётся 70 с. Удержание те же 5 с.", window = 22, trace = 70},
    Journal = {name = "Журнал", slot = "CounterAgent", level = 1, description = "Факт открытия сейфа за раунд; повторное чтение через 2 с.", readCooldown = 2},
    JournalLens = {name = "Лупа архивиста", slot = "CounterAgent", level = 2, description = "Различает открытие в последние 40 с и более старое; чтение раз в 25 с. Без имён.", readCooldown = 25, recent = 40},
    OwnerLedger = {name = "Книга владельца", slot = "Owner", level = 1, description = "Стартовый набор: обычные полномочия пульта."},
    ServingTray = {name = "Поднос", slot = "Staff", level = 1, description = "Стартовый набор: обычное обслуживание."},
    GuestGuide = {name = "Путеводитель", slot = "Guest", level = 1, description = "Стартовый набор: обычные занятия гостя."},
    ObserverTitle = {name = "Наблюдатель", slot = "Title", price = 20, description = "Титул в личном профиле и итогах."},
    HostTitle = {name = "Знаток приёмов", slot = "Title", price = 35, description = "Титул в личном профиле и итогах."},
    TealCard = {name = "Бирюзовая карточка", slot = "Card", price = 25, description = "Бирюзовое оформление профиля и итогов."},
    AmberCard = {name = "Янтарная карточка", slot = "Card", price = 40, description = "Янтарное оформление профиля и итогов."},
}
Catalog.order = {"Lockpick", "Prybar", "Journal", "JournalLens", "OwnerLedger", "ServingTray", "GuestGuide",
    "ObserverTitle", "HostTitle", "TealCard", "AmberCard"}
Catalog.rules = {minimumActive = 45, minimumMoving = 12, minimumActions = 2,
    participationXp = 40, victoryXp = 15, actionXp = 5, actionCap = 4,
    roleXp = 30, roleVictoryXp = 10, tokens = 15, victoryTokens = 5, actionTokens = 2}
return Catalog
