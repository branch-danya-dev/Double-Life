local Events = {}

function Events.start(world, roles, interactions, guard, tell, config, scope)
    local tokens, ready, closesAt = {}, {}, {}
    local function open(part, seconds)
        closesAt[part] = math.max(closesAt[part] or 0, scope:now() + seconds)
        tokens[part] = (tokens[part] or 0) + 1
        local token = tokens[part]
        part.Transparency, part.CanCollide = 0.8, false
        scope:delay(closesAt[part] - scope:now(), function()
            if tokens[part] ~= token then return end
            part.CanCollide = true
            part.Transparency = if part == world.studyWindow then 0.3 else 0
        end)
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
        if guard:command("inspect", Vector3.new(5, 3.5, 55)) then
            -- Keep the return route open through both bounded states, even if the owner leaves.
            open(world.studyDoor, config.INVESTIGATE_SECONDS + config.RETURN_SECONDS + 8)
            tell(player, "Охрана временно проверит кабинет и вернётся к патрулю.")
        else tell(player, "Охрана занята или приказ ещё на перезарядке.") end
    end, Enum.KeyCode.X)
    bind(world.studyWindow, "Открыть окно", "Боковой вход", 5, function(player)
        if roles:get(player) ~= config.ROLE_SPY then tell(player, "Окно заперто. Нужен специальный инструмент."); return end
        local now = scope:now()
        if now < (ready.window or 0) then tell(player, "Механизм окна ещё заклинен. Подождите."); return end
        ready.window = now + config.NOISE_SOURCE_COOLDOWN
        open(world.studyWindow, config.WINDOW_SECONDS)
        guard:react("Window", Vector3.new(-23, 3.5, 58))
        world.studyWindow.Color = Color3.fromRGB(130, 142, 146)
        scope:delay(35, function() world.studyWindow.Color = Color3.fromRGB(69, 107, 124) end)
        tell(player, "Окно открыто ненадолго. Остались следы на раме.")
    end)
    local glass = world.block("BreakableGlass", Vector3.new(0.8, 1.4, 0.8), Vector3.new(21, 2, -17), Color3.fromRGB(165, 209, 221), Enum.Material.Glass)
    glass.Transparency = 0.25
    local glassPrompt
    glassPrompt = bind(glass, "Уронить бокал", "Столик с соком", 1, function()
        local now = scope:now()
        if now < (ready.glass or 0) then return end
        ready.glass = now + config.NOISE_SOURCE_COOLDOWN
        glassPrompt.Enabled, glass.Transparency = false, 1
        local shards = {}
        for i = 1, 4 do
            local shard = world.block("GlassShard", Vector3.new(0.5, 0.1, 0.7), Vector3.new(20 + i * 0.45, 0.6, -17 + i % 2), glass.Color, Enum.Material.Glass)
            shard.CanCollide = false
            table.insert(shards, shard)
        end
        guard:react("Glass", Vector3.new(18, 3.5, -17))
        scope:delay(config.NOISE_SOURCE_COOLDOWN, function()
            for _, shard in ipairs(shards) do shard:Destroy() end
            glassPrompt.Enabled, glass.Transparency = true, 0.25
        end)
    end)
end

return Events
