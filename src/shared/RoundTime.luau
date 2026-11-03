local Time = {}
function Time.format(seconds: number): string
    local value = math.max(0, math.ceil(seconds))
    return string.format("%02d:%02d", math.floor(value / 60), value % 60)
end
function Time.remaining(round): number
    return if round.phase == "Council" then round.activeRemaining else round.remaining
end
function Time.council(round): string
    return "Собрание · осталось " .. math.max(0, math.ceil(round.remaining)) .. " с\nМатч · "
        .. Time.format(round.activeRemaining) .. " · пауза"
end
return Time
