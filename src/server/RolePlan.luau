local Plan = {}
-- Counts are authority, never a public roster of secret roles.
Plan.matrix = {
    [3] = {1, 1, 0, 0, 1}, [4] = {1, 1, 1, 0, 1}, [5] = {1, 1, 1, 1, 1},
    [6] = {1, 1, 1, 1, 2}, [7] = {1, 1, 1, 2, 2},
    [8] = {1, 2, 2, 1, 2}, [9] = {1, 2, 2, 1, 3}, [10] = {1, 2, 2, 2, 3},
    [11] = {1, 2, 2, 2, 4}, [12] = {1, 2, 2, 2, 5}, [13] = {1, 2, 2, 2, 6},
    [14] = {1, 2, 2, 2, 7}, [15] = {1, 2, 2, 2, 8},
}
function Plan.assign(ids, randomIndex, mode)
    local shuffled = table.clone(ids)
    for i = #shuffled, 2, -1 do
        local j = randomIndex(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    local roles = {}
    if #ids < 3 then return roles end
    local composition = {}
    if mode == "M5" then
        for index, role in ipairs({"Owner", "Spy", "CounterAgent", "Staff", "Guest"}) do
            for _ = 1, Plan.matrix[math.min(#ids, 15)][index] do table.insert(composition, role) end
        end
    else -- Preserve the existing MVP API; live Roles explicitly selects the M5 matrix.
        composition = {"Owner", "Spy", "Guest"}
        if #ids >= 4 then composition = {"Owner", "Spy", "CounterAgent", "Guest"} end
        if #ids >= 5 then composition = {"Owner", "Spy", "CounterAgent", "Staff", "Guest"} end
        for i = #composition + 1, math.min(#ids, 15) do composition[i] = "Guest" end
    end
    for i, id in ipairs(shuffled) do if composition[i] then roles[id] = composition[i] end end
    return roles
end
return Plan
