local Events = {}

function Events.start(world, roles, interactions, guard, tell, config, scope, onActivity, tool, onTask)
    local tokens, ready, closesAt = {}, {}, {}
    local function open(part, seconds)
        closesAt[part] = math.max(closesAt[part] or 0, scope:now() + seconds)
        tokens[part] = (tokens[part] or 0) + 1
        local token = tokens[part]
        part.Transparency, part.CanCollide = 0.8, false
        local function closeWhenClear()
            if tokens[part] ~= token then return end
            -- Do not materialize a closed barrier through an R15/NPC standing in it.
            local models = world.npcs:GetChildren()
            for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
                if player.Character then table.insert(models, player.Character) end
            end
            for _, model in ipairs(models) do
                local root = model:FindFirstChild("HumanoidRootPart")
                if root then
                    local p = part.CFrame:PointToObjectSpace(root.Position)
                    if math.abs(p.X) < part.Size.X / 2 + 2 and math.abs(p.Y) < part.Size.Y / 2 + 3
                        and math.abs(p.Z) < part.Size.Z / 2 + 2 then scope:delay(0.5, closeWhenClear); return end
                end
            end
            part.CanCollide = true
            part.Transparency = if part == world.studyWindow then 0.3 else 0
        end
        scope:delay(closesAt[part] - scope:now(), closeWhenClear)
    end
    local function bind(part, action, object, hold, callback, key)
        local p = interactions.prompt(part, action, object, hold)
        if key then p.KeyboardKeyCode = key end
        interactions:bind(p, callback, part.Name == "BreakableGlass")
        return p
    end
    local function owner(player)
        if roles:get(player) == config.ROLE_OWNER then return true end
        tell(player, "Доступ к пульту есть только у владельца.")
        return false
    end
    bind(world.console, "Открыть кабинет", "Пульт владельца", 1, function(player)
        if not owner(player) then return end
        open(world.studyDoor, config.STUDY_DOOR_SECONDS)
        tell(player, "Главная дверь открыта на 20 секунд.")
    end)
    bind(world.console, "Сменить зону патруля", "Пульт владельца", 1, function(player)
        if not owner(player) then return end
        local zone = if guard.policy.zone == "Corridor" then "Foyer" else "Corridor"
        if guard:command("zone", zone) then
            tell(player, "Патруль: " .. (if zone == "Foyer" then "холл" else "коридор") .. ". Перерыв между приказами: 25 с.")
        else tell(player, "Охрана занята или приказ ещё на перезарядке.") end
    end, Enum.KeyCode.Z)
    bind(world.console, "Проверить кабинет", "Пульт владельца", 1, function(player)
        if not owner(player) then return end
        if guard:command("inspect", world:point("Guard.InspectStudy")) then
            -- Keep the return route open through both bounded states, even if the owner leaves.
            open(world.studyDoor, guard.policy.config.INVESTIGATE_SECONDS + guard.policy.config.RETURN_SECONDS + 8)
            tell(player, "Охрана временно проверит кабинет и вернётся к патрулю.")
        else tell(player, "Охрана занята или приказ ещё на перезарядке.") end
    end, Enum.KeyCode.X)
    bind(world.studyWindow, "Открыть окно", "Боковой вход", 5, function(player)
        if roles:get(player) ~= config.ROLE_SPY then tell(player, "Окно заперто. Нужен специальный инструмент."); return end
        local now = scope:now()
        if now < (ready.window or 0) then tell(player, "Механизм окна ещё заклинен. Подождите."); return end
        ready.window = now + config.NOISE_SOURCE_COOLDOWN
        local equipped = tool(player, "Spy")
        open(world.studyWindow, equipped.window)
        guard:react("Window", world:point("Guard.Window"))
        local traceToken = (tokens.trace or 0) + 1
        tokens.trace = traceToken
        world.studyWindow.Color = if equipped.trace > 35 then Color3.fromRGB(190, 144, 80) else Color3.fromRGB(130, 142, 146)
        scope:delay(equipped.trace, function()
            if tokens.trace == traceToken then world.studyWindow.Color = Color3.fromRGB(69, 107, 124) end
        end)
        onTask(player, "Window", 1)
        tell(player, "Проход открыт на " .. equipped.window .. " с; след на раме — " .. equipped.trace .. " с.")
    end)
    local glass = world:object("Glass")
    glass.Transparency = 0.25
    local glassPrompt
    glassPrompt = bind(glass, "Уронить бокал", "Столик с соком", 1, function(player)
        local now = scope:now()
        if now < (ready.glass or 0) then return end
        ready.glass = now + config.NOISE_SOURCE_COOLDOWN
        glassPrompt.Enabled, glass.Transparency = false, 1
        local shards = {}
        for i = 1, 4 do
            local shard = world.block("GlassShard", Vector3.new(0.5, 0.1, 0.7), glass.Position + Vector3.new(-1 + i * 0.45, -1.4, i % 2), glass.Color, Enum.Material.Glass)
            shard.CanCollide = false
            table.insert(shards, shard)
        end
        if guard:react("Glass", world:point("Guard.Glass")) then onActivity(player, "Noise") end
        scope:delay(config.NOISE_SOURCE_COOLDOWN, function()
            for _, shard in ipairs(shards) do shard:Destroy() end
            glassPrompt.Enabled, glass.Transparency = true, 0.25
        end)
    end)
    return {open = open}
end

return Events
