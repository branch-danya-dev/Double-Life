-- Public queue copy deliberately has no population counters. The authoritative
-- snapshot still carries the real human count for server rules and telemetry.
local Presentation = {}
local states = {
    Lobby = "Приёмная\nОсмотритесь или встаньте в очередь.",
    Queued = "Подбор участников\nПока идёт поиск, можно исследовать поместье.",
    MatchReady = "Матч готов\nПрисоединитесь, когда будете готовы.",
    Active = "Матч идёт\nВы сможете участвовать в следующем раунде.",
}
function Presentation.status(queue)
    if queue.transport == "MatchmakingFailed" or queue.transport == "TransportFailed" then
        return "Связь с подбором прервана. Повторяем поиск; вы остаётесь в приёмной."
    end
    return states[queue.state] or states.Lobby
end
return Presentation
