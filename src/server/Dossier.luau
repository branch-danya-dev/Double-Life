local Dossier = {}
function Dossier.start(world, roles, interactions, personalUpdate, tell, Config, finish, evidence, onTask, onActivity)
    local safe, gold, block = world.safe, world.gold, world.block
    local prompt = interactions.prompt
    local function usePrompt(p, f, neutral) interactions:bind(p, f, neutral) end
    local safePrompt = prompt(safe, "Осмотреть", "Сейф с документами", 2)
    local dossierMissing, carrierId = false, nil
    local opened = false
    local seenPaintings = {}
    local function paintingCount(userId)
        local count = 0
        for _ in pairs(seenPaintings[userId] or {}) do count += 1 end
        return count
    end
    -- No Tool/attribute: carrier identity stays on the server.
    local function resetDossier()
        carrierId, dossierMissing = nil, false
        safe.Color = gold
    end

    usePrompt(safePrompt, function(player)
        if dossierMissing then
            tell(player, "Сейф открыт. Документы исчезли.")
        elseif roles:get(player) == Config.ROLE_SPY then
            dossierMissing = true
            opened = true
            carrierId = player.UserId
            safe.Color = Color3.fromRGB(96, 88, 71)
            evidence:create()
            if dossierMissing then
                tell(player, "Досье у вас. Доберитесь до выхода из особняка.")
            end
        else
            tell(player, "Документы на месте.")
        end
    end)

    local logbook = world.logbook
    usePrompt(prompt(logbook, "Изучить журнал", "Журнал проверок", 1), function(player)
        if roles:get(player) ~= Config.ROLE_AGENT then
            tell(player, "Журнал защищён. Для чтения требуется допуск контрразведки.")
        elseif opened then
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
