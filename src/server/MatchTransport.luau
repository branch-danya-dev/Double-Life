local Transport = {}
function Transport.new(settings)
    local studio = game:GetService("RunService"):IsStudio()
    local enabled = settings.crossServerEnabled and not studio and settings.stagingUniverseId > 0
        and game.GameId == settings.stagingUniverseId and game.PlaceId == settings.stagingPlaceId
    local self = {enabled=enabled, mode=if enabled then "Staging" else "Local", failures=0}
    if not enabled then return self end
    local map=game:GetService("MemoryStoreService"):GetHashMap(settings.memoryNamespace)
    function self:update(transform) return map:UpdateAsync("pool", transform, settings.assignmentLease*2) end
    function self:send(player, target, matchId, token)
        local options=Instance.new("TeleportOptions")
        options.ServerInstanceId=target
        options:SetTeleportData({matchId=matchId,ticket=token})
        game:GetService("TeleportService"):TeleportAsync(settings.stagingPlaceId,{player},options)
    end
    return self
end
return Transport
