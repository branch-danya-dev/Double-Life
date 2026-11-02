local Dossier = {}
function Dossier.start(world, roles, interactions, personalUpdate, tell, Config, state)
    local Players = game:GetService("Players")
    local safe, gold, block = world.safe, world.gold, world.block
    local prompt = interactions.prompt
    local function usePrompt(p, f) interactions:bind(p, f) end
    local safePrompt = prompt(safe, "Осмотреть", "Сейф с документами", 2)
    local dossierMissing, carrierId = false, nil
    local seenPaintings = {}
    local function paintingCount(userId)
        local count = 0
        for _ in pairs(seenPaintings[userId] or {}) do count += 1 end
        return count
    end
    local function announceResult(message)
        personalUpdate:FireAllClients("Result", message)
    end
    local function removeFileTool(player)
        if not player then
            return
        end
        for _, container in pairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
            if container then
                local tool = container:FindFirstChild("DoubleLifeDossier")
                if tool then
                    tool:Destroy()
                end
            end
        end
    end

    local function resetDossier()
        if carrierId then
            removeFileTool(Players:GetPlayerByUserId(carrierId))
        end
        carrierId = nil
        dossierMissing = false
        safe.Color = gold
    end

    local function giveDossier(player)
        local tool = Instance.new("Tool")
        tool.Name = "DoubleLifeDossier"
        tool.ToolTip = "Секретное досье"
        tool.CanBeDropped = false

        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(1.5, 0.2, 1.1)
        handle.Color = Color3.fromRGB(28, 31, 38)
        handle.Material = Enum.Material.SmoothPlastic
        handle.CanCollide = false
        handle.Parent = tool

        local backpack = player:FindFirstChildOfClass("Backpack")
        if backpack then
            tool.Parent = backpack
        else
            tool:Destroy()
            resetDossier()
        end
    end

    usePrompt(safePrompt, function(player)
        if dossierMissing then
            tell(player, "Сейф открыт. Документы исчезли.")
        elseif roles:get(player) == Config.ROLE_SPY then
            dossierMissing = true
            carrierId = player.UserId
            safe.Color = Color3.fromRGB(96, 88, 71)
            giveDossier(player)
            if dossierMissing then
                tell(player, "Досье у вас. Доберитесь до выхода из особняка.")
            end
        else
            tell(player, "Документы на месте. Следов взлома не видно.")
        end
    end)

    local logbook = world.logbook
    usePrompt(prompt(logbook, "Изучить журнал", "Журнал проверок", 1), function(player)
        if roles:get(player) ~= Config.ROLE_AGENT then
            tell(player, "Журнал защищён. Для чтения требуется допуск контрразведки.")
        elseif dossierMissing then
            tell(player, "Журнал показывает недавнее открытие сейфа, но не имя посетителя.")
        else
            tell(player, "Записи о недавнем открытии сейфа отсутствуют.")
        end
    end)

    -- Neutral guest activity: identical interactions for all roles, no role revelation.
    for index, z in ipairs({ -15, 0, 15 }) do
        local painting = block("Painting" .. index, Vector3.new(0.6, 4, 4), Vector3.new(-27.2, 5.5, z), Color3.fromRGB(100 + index * 25, 98, 87))
        local paintingPrompt = prompt(painting, "Осмотреть", "Картина " .. index, 0.75)
        usePrompt(paintingPrompt, function(player)
            local visited = seenPaintings[player.UserId]
            if not visited then
                return
            end
            if visited[index] then
                tell(player, "Вы уже осматривали эту картину.")
                return
            end
            visited[index] = true
            local count = paintingCount(player.UserId)
            personalUpdate:FireClient(player, "PaintingProgress", count)
            if count == Config.GUEST_PAINTINGS then
                tell(player, "Все картины осмотрены. Это тестовое поручение; валюта пока не сохраняется.")
            else
                tell(player, "Картина осмотрена: " .. count .. "/" .. Config.GUEST_PAINTINGS)
            end
        end)
    end

    local exitDoor = world.exitDoor
    usePrompt(prompt(exitDoor, "Покинуть особняк", "Главный выход", 1.5), function(player)
        if roles:get(player) ~= Config.ROLE_SPY or carrierId ~= player.UserId then
            tell(player, "Для завершения операции необходимы украденные документы.")
            return
        end
        state.finished = true
        announceResult("Шпион вынес досье из особняка. Раунд прототипа завершён.")
        task.delay(Config.RESULT_RESET_SECONDS, function()
            resetDossier()
            state.finished = false
            announceResult("Сейф восстановлен. Следующая проверка может начаться.")
        end)
    end)


    local api = {}
    function api:add(player) seenPaintings[player.UserId] = {} end
    function api:resetCharacter(player)
        if carrierId == player.UserId then resetDossier() end
    end
    function api:remove(player)
        self:resetCharacter(player)
        seenPaintings[player.UserId] = nil
    end
    function api:count(player) return paintingCount(player.UserId) end
    return api
end
return Dossier
