local Actor = {}
function Actor.mimicCount(humans, target, maximum)
    if humans < 1 then return 0 end
    return math.clamp(math.min(15 - humans, target - humans), 0, maximum)
end
function Actor.human(id, player)
    return {kind = "Human", id = id, player = player}
end
function Actor.mimic(id: string, model, name)
    assert(type(id) == "string" and string.match(id, "^m:%d+$"), "Separate mimic identity")
    return {kind = "Mimic", id = id, model = model, name = name, role = "Guest"}
end
function Actor.canProfile(actor) return actor ~= nil and actor.kind == "Human" and actor.player ~= nil end
function Actor.canVote(actor) return Actor.canProfile(actor) end
return Actor
