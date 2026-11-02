-- Targeted final audit: exercise the same shutdown path bound by ProfileService, then reload.
local Audit = {}
function Audit.run(rt)
    local Players = game:GetService("Players")
    local Schema = require(game.ServerScriptService.DoubleLifeServer.ProfileSchema)
    local before, exported = {}, {}
    for _, player in ipairs(Players:GetPlayers()) do
        local p = rt.profiles:entry(player).profile
        before[player.UserId] = {tokens = p.tokens, reputationXp = p.reputationXp, played = p.stats.played}
    end
    assert(rt.profiles:shutdown(), "shutdown must finish within its deadline")
    for _, player in ipairs(Players:GetPlayers()) do
        assert(rt.profiles.adapter.data["User_" .. player.UserId].lease.expires == 0, "shutdown releases every lease")
        rt.profiles:add(player)
    end
    local deadline = os.clock() + 10
    for _, player in ipairs(Players:GetPlayers()) do
        repeat task.wait(0.1) until (rt.profiles:entry(player) and rt.profiles:entry(player).status == "Ready") or os.clock() >= deadline
        local e = rt.profiles:entry(player)
        assert(e and e.status == "Ready", "profile reload after shutdown")
        local p, old = e.profile, before[player.UserId]
        assert(p.tokens == old.tokens and p.reputationXp == old.reputationXp and p.stats.played == old.played, "confirmed economy preserved")
        exported[player.Name] = {reputationXp = p.reputationXp, tokens = p.tokens, roleXp = Schema.copy(p.roleXp),
            stats = Schema.copy(p.stats), inventory = Schema.copy(p.inventory), equipped = Schema.copy(p.equipped),
            achievements = Schema.copy(p.achievements), historyCount = #p.history}
    end
    for name, data in pairs(exported) do
        print("M4 STORE ACCOUNT " .. name .. " " .. game:GetService("HttpService"):JSONEncode(data))
    end
    print("M4 STORE AUDIT PASS: shutdown released all leases; reload preserved confirmed accounts")
end
return Audit
