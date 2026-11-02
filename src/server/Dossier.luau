local Dossier = {}
function Dossier.start(world, roles, interactions, personalUpdate, tell, Config, finish, evidence, onTask, onActivity, scope, tool)
    local safe, gold = world.safe, world.gold
    local prompt = interactions.prompt
    local function usePrompt(p, f, neutral) interactions:bind(p, f, neutral) end
    local safePrompt = prompt(safe, "Осмотреть", "Сейф с документами", 2)
    local dossierMissing, carrierId = false, nil
    local opened = false
    local openedAt, nextRead = 0, {}
    local carryGeneration = 0
    local seenPaintings = {}
    local function paintingCount(userId)
        local count = 0
        for _ in pairs(seenPaintings[userId] or {}) do count += 1 end
        return count
    end
    -- No Tool/attribute: carrier identity stays on the server.
    local function resetDossier()
        carryGeneration += 1
        carrierId, dossierMissing = nil, false
        safe.Color = gold
    end

    usePrompt(safePrompt, function(player)
        if dossierMissing then
            tell(player, "Сейф открыт. Документы исчезли.")
        elseif roles:get(player) == Config.ROLE_SPY then
            dossierMissing = true
            opened = true
            openedAt = scope:now()
            carrierId = player.UserId
            carryGeneration += 1
            local generation = carryGeneration
            scope:delay(Config.DOSSIER_CARRY_SECONDS, function()
                if generation == carryGeneration and carrierId then
                    resetDossier()
                    tell(player, "Срок операции с досье истёк: оно возвращено в сейф. Попытку можно повторить.")
                end
            end)
            safe.Color = Color3.fromRGB(96, 88, 71)
            evidence:create()
            onTask(player, "Safe", 1)
            if dossierMissing then
                tell(player, "Досье у вас. До выхода: " .. Config.DOSSIER_CARRY_SECONDS .. " с активной игры; затем возврат в сейф, даже если вы двигаетесь.")
            end
        else
            tell(player, "Документы на месте.")
        end
    end)

    local logbook = world.logbook
    usePrompt(prompt(logbook, "Изучить журнал", "Журнал проверок", 1), function(player)
        if roles:get(player) ~= Config.ROLE_AGENT then
            tell(player, "Журнал защищён. Для чтения требуется допуск контрразведки.")
        else
            local equipped = tool(player, "CounterAgent")
            if scope:now() < (nextRead[player.UserId] or 0) then tell(player, "Подождите перед повторным чтением журнала."); return end
            nextRead[player.UserId] = scope:now() + equipped.readCooldown
            onTask(player, "Journal", 1)
            if not opened then tell(player, "Записи об открытии сейфа отсутствуют.")
            elseif equipped.recent then
                tell(player, if scope:now() - openedAt <= equipped.recent then "Сейф открывали в последние 40 секунд. Имя неизвестно."
                    else "Сейф открывали более 40 секунд назад. Имя неизвестно.")
            else tell(player, "Сейф открывали в этом раунде. Имя посетителя неизвестно.") end
        end
    end)

    -- Neutral guest activity: identical interactions for all roles, no role revelation.
    for index, id in ipairs(world.layout.groups.Paintings) do
        local painting = world:object(id)
        local paintingPrompt = prompt(painting, "Осмотреть", "Картина " .. index, 0.75)
        usePrompt(paintingPrompt, function(player)
            local visited = seenPaintings[player.UserId]
            if not visited then
                return
            end
            onActivity(player, "Painting" .. index)
            if visited[index] then
                tell(player, "Вы уже осматривали эту картину.")
                return
            end
            visited[index] = true
            onTask(player, "Painting", 1)
            local count = paintingCount(player.UserId)
            personalUpdate:FireClient(player, "PaintingProgress", count)
            if count == Config.GUEST_PAINTINGS then
                tell(player, "Личная цель выполнена: три картины осмотрены.")
            else
                tell(player, "Картина осмотрена: " .. count .. "/" .. Config.GUEST_PAINTINGS)
            end
        end, true)
    end

    local exitDoor = world.exitDoor
    usePrompt(prompt(exitDoor, "Покинуть особняк", "Главный выход", 1.5), function(player)
        if roles:get(player) ~= Config.ROLE_SPY or carrierId ~= player.UserId then
            tell(player, "Для завершения операции необходимы украденные документы.")
            return
        end
        finish(player.UserId)
    end)


    local api = {}
    function api:add(player) seenPaintings[player.UserId] = {} end
    function api:resetCharacter(player)
        if carrierId == player.UserId then resetDossier() end
    end
    function api:remove(player)
        self:resetCharacter(player)
        seenPaintings[player.UserId] = nil
        nextRead[player.UserId] = nil
    end
    function api:search(player)
        if carrierId ~= player.UserId then return false end
        resetDossier()
        tell(player, "После досмотра досье вернулось в сейф. Операцию можно продолжить.")
        return true
    end
    function api:has(player) return carrierId == player.UserId end
    function api:count(player) return paintingCount(player.UserId) end
    return api
end
return Dossier
