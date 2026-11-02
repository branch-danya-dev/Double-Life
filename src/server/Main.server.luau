-- Double Life M0: server-authoritative, two-route dossier theft prototype.
-- Generated geometry is intentionally temporary; replace it with authored rooms later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("DoubleLifeShared"):WaitForChild("Config"))

local remotes = Instance.new("Folder")
remotes.Name = "DoubleLifeRemotes"
remotes.Parent = ReplicatedStorage

local personalUpdate = Instance.new("RemoteEvent")
personalUpdate.Name = "PersonalUpdate"
personalUpdate.Parent = remotes

local getState = Instance.new("RemoteFunction")
getState.Name = "GetState"
getState.Parent = remotes

local roles = {}
local seenPaintings = {}
local ownerId = nil
local spyId = nil
local agentId = nil

local dossierMissing = false
local carrierId = nil
local missionFinished = false
local doorToken = 0
local windowToken = 0

local function tell(player, message)
	personalUpdate:FireClient(player, "Notice", message)
end

local function announceResult(message)
	for _, player in ipairs(Players:GetPlayers()) do
		personalUpdate:FireClient(player, "Result", message)
	end
end

local function paintingCount(userId)
	local entries = seenPaintings[userId]
	local count = 0
	if entries then
		for _ in pairs(entries) do
			count += 1
		end
	end
	return count
end

getState.OnServerInvoke = function(player)
	return {
		role = roles[player.UserId] or Config.ROLE_GUEST,
		paintings = paintingCount(player.UserId),
		requiredPaintings = Config.GUEST_PAINTINGS,
	}
end

local function setRole(player, role)
	roles[player.UserId] = role
	personalUpdate:FireClient(player, "Role", role)
end

local function assignRole(player)
	local role
	if not ownerId then
		ownerId = player.UserId
		role = Config.ROLE_OWNER
	elseif not spyId then
		spyId = player.UserId
		role = Config.ROLE_SPY
	elseif not agentId then
		agentId = player.UserId
		role = Config.ROLE_AGENT
	else
		role = Config.ROLE_GUEST
	end
	setRole(player, role)
	seenPaintings[player.UserId] = {}
end

local map = Instance.new("Folder")
map.Name = "DoubleLifePrototype"
map.Parent = workspace

local function block(name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	part.Parent = map
	return part
end

local stone = Color3.fromRGB(68, 69, 74)
local floorColor = Color3.fromRGB(100, 76, 59)
local wood = Color3.fromRGB(55, 33, 28)
local gold = Color3.fromRGB(192, 153, 74)

local function wall(name, size, position)
	return block(name, size, position, stone, Enum.Material.Brick)
end

local function prompt(part, action, object, hold)
	local item = Instance.new("ProximityPrompt")
	item.ActionText = action
	item.ObjectText = object
	item.HoldDuration = hold or 0.5
	item.MaxActivationDistance = 10
	item.RequiresLineOfSight = false
	item.Parent = part
	return item
end

local function inReach(player, attachedPrompt)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local host = attachedPrompt.Parent
	return root ~= nil
		and host ~= nil
		and (root.Position - host.Position).Magnitude <= attachedPrompt.MaxActivationDistance + 4
end

local function usePrompt(attachedPrompt, callback)
	attachedPrompt.Triggered:Connect(function(player)
		if missionFinished or not inReach(player, attachedPrompt) then
			return
		end
		callback(player)
	end)
end

-- One foyer, one study, an owner's door, and a second exterior infiltration route.
block("ExteriorGround", Vector3.new(110, 1, 150), Vector3.new(0, -1, 20), Color3.fromRGB(43, 62, 48), Enum.Material.Grass)
block("FoyerFloor", Vector3.new(56, 1, 56), Vector3.new(0, 0, 0), floorColor, Enum.Material.WoodPlanks)
block("StudyFloor", Vector3.new(36, 1, 36), Vector3.new(0, 0, 58), floorColor, Enum.Material.WoodPlanks)
block("PassageFloor", Vector3.new(12, 1, 14), Vector3.new(0, 0, 34), floorColor, Enum.Material.WoodPlanks)

wall("FoyerWest", Vector3.new(1, 12, 56), Vector3.new(-28, 6, 0))
wall("FoyerEast", Vector3.new(1, 12, 56), Vector3.new(28, 6, 0))
wall("FoyerNorthLeft", Vector3.new(22, 12, 1), Vector3.new(-17, 6, 28))
wall("FoyerNorthRight", Vector3.new(22, 12, 1), Vector3.new(17, 6, 28))
wall("FoyerSouthLeft", Vector3.new(23, 12, 1), Vector3.new(-16.5, 6, -28))
wall("FoyerSouthRight", Vector3.new(23, 12, 1), Vector3.new(16.5, 6, -28))
wall("PassageLeft", Vector3.new(1, 12, 12), Vector3.new(-6, 6, 34))
wall("PassageRight", Vector3.new(1, 12, 12), Vector3.new(6, 6, 34))
wall("StudyNorth", Vector3.new(36, 12, 1), Vector3.new(0, 6, 76))
wall("StudyEast", Vector3.new(1, 12, 36), Vector3.new(18, 6, 58))
wall("StudySouthLeft", Vector3.new(14, 12, 1), Vector3.new(-11, 6, 40))
wall("StudySouthRight", Vector3.new(14, 12, 1), Vector3.new(11, 6, 40))
wall("StudyWestLower", Vector3.new(1, 12, 14), Vector3.new(-18, 6, 47))
wall("StudyWestUpper", Vector3.new(1, 12, 14), Vector3.new(-18, 6, 69))

local studyDoor = block("StudyDoor", Vector3.new(8, 11, 1), Vector3.new(0, 5.5, 40), wood)
local studyWindow = block("StudyWindow", Vector3.new(1, 11, 8), Vector3.new(-18, 5.5, 58), Color3.fromRGB(69, 107, 124), Enum.Material.Glass)
studyWindow.Transparency = 0.3

local function openTemporarily(part, seconds, which)
	if which == "door" then
		doorToken += 1
	else
		windowToken += 1
	end
	local token = if which == "door" then doorToken else windowToken
	part.Transparency = 0.8
	part.CanCollide = false
	task.delay(seconds, function()
		if (which == "door" and doorToken ~= token) or (which == "window" and windowToken ~= token) then
			return
		end
		part.CanCollide = true
		part.Transparency = if which == "door" then 0 else 0.3
	end)
end

local console = block("OwnerAccessConsole", Vector3.new(2, 3, 2), Vector3.new(3.5, 2, 33), gold, Enum.Material.Metal)
usePrompt(prompt(console, "Открыть кабинет", "Пульт владельца", 1), function(player)
	if roles[player.UserId] ~= Config.ROLE_OWNER then
		tell(player, "Доступ к пульту есть только у владельца.")
		return
	end
	openTemporarily(studyDoor, Config.STUDY_DOOR_SECONDS, "door")
	tell(player, "Главная дверь открыта на 20 секунд.")
end)

usePrompt(prompt(studyWindow, "Открыть окно", "Боковой вход", 5), function(player)
	if roles[player.UserId] ~= Config.ROLE_SPY then
		tell(player, "Окно заперто. Нужен специальный инструмент.")
		return
	end
	openTemporarily(studyWindow, Config.WINDOW_SECONDS, "window")
	tell(player, "Окно открыто ненадолго. Действуйте быстро.")
end)

local safe = block("DocumentSafe", Vector3.new(5, 4, 3), Vector3.new(0, 2.5, 65), gold, Enum.Material.Metal)
local safePrompt = prompt(safe, "Осмотреть", "Сейф с документами", 2)

local function removeFileTool(player)
	if not player then
		return
	end
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
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
	elseif roles[player.UserId] == Config.ROLE_SPY then
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

local logbook = block("ForensicLog", Vector3.new(2, 1, 2), Vector3.new(8, 2, 64), Color3.fromRGB(129, 96, 73))
usePrompt(prompt(logbook, "Изучить журнал", "Журнал проверок", 1), function(player)
	if roles[player.UserId] ~= Config.ROLE_AGENT then
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

local exitDoor = block("EstateExit", Vector3.new(9, 10, 1), Vector3.new(0, 5, -28), Color3.fromRGB(36, 83, 69), Enum.Material.Metal)
exitDoor.CanCollide = false -- The exterior route must remain physically reachable.
exitDoor.Transparency = 0.35
usePrompt(prompt(exitDoor, "Покинуть особняк", "Главный выход", 1.5), function(player)
	if roles[player.UserId] ~= Config.ROLE_SPY or carrierId ~= player.UserId then
		tell(player, "Для завершения операции необходимы украденные документы.")
		return
	end
	missionFinished = true
	announceResult("Шпион вынес досье из особняка. Раунд прототипа завершён.")
	task.delay(Config.RESULT_RESET_SECONDS, function()
		resetDossier()
		missionFinished = false
		announceResult("Сейф восстановлен. Следующая проверка может начаться.")
	end)
end)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "FoyerSpawn"
spawn.Size = Vector3.new(7, 1, 7)
spawn.Position = Vector3.new(0, 1, -16)
spawn.Anchored = true
spawn.Neutral = true
spawn.Material = Enum.Material.Neon
spawn.Color = Color3.fromRGB(117, 132, 117)
spawn.Parent = map

Lighting.ClockTime = 19.5
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(85, 88, 105)

Players.PlayerAdded:Connect(function(player)
	assignRole(player)
	player.CharacterAdded:Connect(function()
		if carrierId == player.UserId then
			resetDossier()
			tell(player, "При потере персонажа досье возвращается в сейф.")
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	if carrierId == userId then
		resetDossier()
	end
	roles[userId] = nil
	seenPaintings[userId] = nil
	if ownerId == userId then
		ownerId = nil
	elseif spyId == userId then
		spyId = nil
	elseif agentId == userId then
		agentId = nil
	end

	-- Preserve a playable session when someone leaves; never publish hidden roles.
	for _, remaining in ipairs(Players:GetPlayers()) do
		if remaining ~= player then
			local role = roles[remaining.UserId]
			if not ownerId and role == Config.ROLE_GUEST then
				ownerId = remaining.UserId
				setRole(remaining, Config.ROLE_OWNER)
			elseif not spyId and role == Config.ROLE_GUEST then
				spyId = remaining.UserId
				setRole(remaining, Config.ROLE_SPY)
			elseif not agentId and role == Config.ROLE_GUEST then
				agentId = remaining.UserId
				setRole(remaining, Config.ROLE_AGENT)
			end
		end
	end
end)

-- Covers Studio hot-reload cases where players already exist.
for _, player in ipairs(Players:GetPlayers()) do
	if not roles[player.UserId] then
		assignRole(player)
	end
end
