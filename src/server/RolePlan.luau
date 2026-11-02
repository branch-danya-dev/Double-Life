local Plan = {}
function Plan.assign(ids, randomIndex)
    local shuffled = table.clone(ids)
    for i = #shuffled, 2, -1 do
        local j = randomIndex(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    local roles = {}
    if #ids < 3 then return roles end
    local composition = {"Owner", "Spy", "Guest"}
    if #ids >= 4 then composition = {"Owner", "Spy", "CounterAgent", "Guest"} end
    if #ids >= 5 then composition = {"Owner", "Spy", "CounterAgent", "Staff", "Guest"} end
    for i, id in ipairs(shuffled) do roles[id] = composition[i] or "Guest" end
    return roles
end
return Plan
