-- Client only displays the local player's role, never anyone else's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
player.CameraMode = Enum.CameraMode.LockFirstPerson

local remotes = ReplicatedStorage:WaitForChild("DoubleLifeRemotes")
local personalUpdate = remotes:WaitForChild("PersonalUpdate")
local getState = remotes:WaitForChild("GetState")

local names = {
	Owner = "Владелец",
	Spy = "Шпион",
	CounterAgent = "Контрразведчик",
	Guest = "Гость",
}

local gui = Instance.new("ScreenGui")
gui.Name = "DoubleLifeHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "StatusPanel"
container.AnchorPoint = Vector2.new(0, 0)
container.Position = UDim2.new(0, 14, 0, 18)
container.Size = UDim2.new(0.86, 0, 0, 112)
container.BackgroundColor3 = Color3.fromRGB(19, 21, 28)
container.BackgroundTransparency = 0.15
container.Parent = gui

local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(440, 112)
limit.Parent = container

local function label(name, y, height, size, color)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = UDim2.fromOffset(12, y)
	item.Size = UDim2.new(1, -24, 0, height)
	item.Font = Enum.Font.Gotham
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextSize = size
	item.TextColor3 = color
	item.TextWrapped = true
	item.Parent = container
	return item
end

local title = label("Title", 8, 24, 18, Color3.fromRGB(238, 229, 201))
title.Text = "DOUBLE LIFE · M0"

local roleLabel = label("Role", 36, 20, 14, Color3.fromRGB(225, 226, 228))
roleLabel.Text = "Роль: загрузка..."

local progressLabel = label("Activity", 57, 18, 13, Color3.fromRGB(180, 198, 186))
progressLabel.Text = "Осмотр картин: 0/3"

local noticeLabel = label("Notice", 79, 27, 12, Color3.fromRGB(246, 209, 131))
noticeLabel.Text = "Взаимодействуйте с предметами через подсказку."

local function updateRole(role)
	roleLabel.Text = "Ваша роль: " .. (names[role] or role)
end

personalUpdate.OnClientEvent:Connect(function(kind, value)
	if kind == "Role" then
		updateRole(value)
	elseif kind == "PaintingProgress" then
		progressLabel.Text = "Осмотр картин: " .. tostring(value) .. "/3"
	elseif kind == "Notice" or kind == "Result" then
		noticeLabel.Text = value
	end
end)

local ok, snapshot = pcall(function()
	return getState:InvokeServer()
end)
if ok and snapshot then
	updateRole(snapshot.role)
	progressLabel.Text = "Осмотр картин: " .. tostring(snapshot.paintings) .. "/" .. tostring(snapshot.requiredPaintings)
end
