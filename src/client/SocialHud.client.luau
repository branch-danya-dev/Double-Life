local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local Marketplace = game:GetService("MarketplaceService")
local player = Players.LocalPlayer
local remotes = RS:WaitForChild("DoubleLifeRemotes")
local social, commerce = remotes:WaitForChild("SocialAction"), remotes:WaitForChild("CommerceAction")
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Parent = "DoubleLifeSocial", false, 5, player:WaitForChild("PlayerGui")
local panel = Instance.new("ScrollingFrame")
panel.Name, panel.Size, panel.Position, panel.AnchorPoint = "SocialShopPanel", UDim2.fromScale(0.8, 0.75), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
panel.BackgroundColor3, panel.ScrollBarThickness, panel.Visible, panel.Parent = Color3.fromRGB(23, 29, 36), 6, false, gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize, limit.Parent = Vector2.new(620, 600), panel
local shortcut = Instance.new("TextButton")
shortcut.Name, shortcut.Size, shortcut.Position, shortcut.Text = "SocialShortcut", UDim2.fromOffset(235, 32), UDim2.new(1, -245, 0, 10), "J действия · K статус / магазин"
shortcut.BackgroundColor3, shortcut.TextColor3, shortcut.Parent = Color3.fromRGB(36, 55, 64), Color3.new(1, 1, 1), gui
local state, mode, lastKey, showEffects = nil, "Social", "", true
local prices, fetching, boards = {}, {}, {}
local render
local function requestPrice(key, offer)
    if offer.id <= 0 or fetching[key] or (prices[key] and os.clock() < prices[key].expires) then return end
    fetching[key] = true
    task.spawn(function()
        local ok, value = pcall(function()
            return Marketplace:GetProductInfoAsync(offer.id, if offer.kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
        end)
        prices[key] = {expires = os.clock() + 30, text = if ok and value.IsForSale and type(value.PriceInRobux) == "number"
            then tostring(value.PriceInRobux) .. " Robux" else "недоступно"}
        fetching[key], lastKey = nil, ""
        render()
    end)
end
local function toggle(which)
    if not state then return end
    panel.Visible = not panel.Visible or mode ~= which
    mode, lastKey = which, ""
    if panel.Visible and which == "Shop" then commerce:FireServer("Open") end
    render()
end
shortcut.Activated:Connect(function() toggle(if state and state.round.phase == "Active" then "Social" else "Shop") end)
render = function()
    if not state or not panel.Visible then return end
    local key = game:GetService("HttpService"):JSONEncode({state.social, state.commerce, state.round.members, state.round.phase, mode, showEffects})
    if key == lastKey then return end
    lastKey = key
    for _, child in ipairs(panel:GetChildren()) do if not child:IsA("UISizeConstraint") then child:Destroy() end end
    local y = 10
    local function line(value, height)
        local text = Instance.new("TextLabel")
        text.Size, text.Position, text.Text, text.TextWrapped = UDim2.new(1, -24, 0, height or 40), UDim2.fromOffset(12, y), value, true
        text.TextColor3, text.BackgroundTransparency, text.Font, text.TextSize = Color3.fromRGB(238, 234, 219), 1, Enum.Font.Gotham, 14
        text.Parent, y = panel, y + (height or 40) + 5
    end
    local function button(value, callback)
        local b = Instance.new("TextButton")
        b.Size, b.Position, b.Text, b.TextWrapped, b.Modal = UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, y), value, true, true
        b.BackgroundColor3, b.TextColor3, b.TextSize, b.Font, b.Parent = Color3.fromRGB(54, 78, 83), Color3.new(1, 1, 1), 14, Enum.Font.Gotham, panel
        b.Activated:Connect(callback)
        y += 42
    end
    button("Закрыть [J / K]", function() panel.Visible = false end)
    if mode == "Social" then
        line("Без слов: доступ → экспонат → след → проверка", 35)
        line("У пульта владелец выбирает получателя пропуска. Получатель прикладывает его к считывателю у двери; другие могут пройти следом. Экспонат из кабинета доставляют к зелёной стойке в холле.", 90)
        line("Пропуск: " .. state.social.passSeconds .. " с · в руках: " .. (state.social.held or "ничего") .. ". Предмет вернётся на место через 45 с; передача рядом и по согласию.", 55)
        if state.round.phase == "Active" and state.round.participating then
            local roundId = state.round.roundId
            for keyName, label in pairs({Here = "↓ Сюда", Wait = "… Подожди", Help = "! Помоги", Suspicious = "? Подозрительно"}) do
                button(label .. " · знак на 3 с, перерыв 8 с", function() social:FireServer("Signal", keyName, roundId) end)
            end
            if state.social.held then button("Положить предмет", function() social:FireServer("Drop", nil, roundId) end) end
            if state.social.offer then
                button("Принять: " .. state.social.offer.item .. " от участника рядом", function() social:FireServer("Accept", state.social.offer.from, roundId) end)
            end
            for _, member in ipairs(state.round.members) do
                if member.id ~= player.UserId then
                    if state.role == "Owner" then button("Пропуск → " .. member.name .. " · осталось " .. state.social.grants,
                        function() social:FireServer("Grant", member.id, roundId) end) end
                    if state.social.held then button("Предложить предмет → " .. member.name, function() social:FireServer("Offer", member.id, roundId) end) end
                end
            end
        else line("Действия доступны участникам активного раунда.") end
        line("Ткань на стойке в холле можно оставить у внешней рамы окна: удержание 3 с, максимум дважды. След не доказывает вину. Агент проверяет считыватель, место экспоната и ткань клавишей F.", 90)
    else
        local c = state.commerce
        line("Социальный профиль · только косметика", 35)
        line("Титулы и рамки видны над аватарами в ожидании и итогах. Жетонные варианты: P. Преимуществ в раунде нет.", 60)
        local socialPhase = state.round.phase == "Waiting" or state.round.phase == "Results"
        button(if showEffects then "Скрыть чужие праздничные эффекты" else "Показывать праздничные эффекты", function() showEffects = not showEffects; lastKey = ""; render() end)
        if socialPhase then button("Бесплатное приветствие · 3 с", function() commerce:FireServer("Wave") end) end
        if not c.enabled then line("Покупки Robux НЕДОСТУПНЫ. Товары ещё не подключены; проверка реального хранилища не завершена.", 65) end
        for _, offerKey in ipairs({"Supporter", "Celebration"}) do
            local offer = c.offers[offerKey]
            if c.enabled then requestPrice(offerKey, offer) end
            local name = if offerKey == "Supporter" then "Supporter · постоянные титул и рамка" else "Праздничный эффект · 1 сохраняемый заряд"
            line(name .. " · " .. (if not c.enabled or offer.id == 0 then "недоступно" else prices[offerKey] and prices[offerKey].text or "получаем цену…"), 48)
            if c.ready and socialPhase and prices[offerKey] and prices[offerKey].text ~= "недоступно" and not (offerKey == "Supporter" and c.supporter) then
                button("Открыть окно Roblox", function() commerce:FireServer("Prompt", offerKey) end)
            end
        end
        if c.ready and socialPhase then
            if c.supporter then button(if c.selected then "Снять оформление Supporter" else "Показать Supporter", function() commerce:FireServer("Style", not c.selected) end) end
            line("Заряды: " .. c.charges .. (if c.pendingEffect then " · эффект ожидает показа" else ""))
            if c.charges > 0 then button("Использовать праздничный эффект · 4 с, перерыв 60 с", function() commerce:FireServer("Effect") end) end
        end
        line("Цена приходит от Roblox для вашего региона; окончательная цена — в окне покупки. Эффект виден только рядом, его можно скрыть. Во время раунда он не работает.", 75)
    end
    panel.CanvasSize = UDim2.fromOffset(0, y + 5)
end
local colors = {TealCard = Color3.fromRGB(32, 127, 128), AmberCard = Color3.fromRGB(159, 112, 39), Supporter = Color3.fromRGB(125, 75, 164)}
local function snapshot(value)
    state = value
    local socialPhase = value.round.phase == "Waiting" or value.round.phase == "Results"
    player.CameraMode = if socialPhase then Enum.CameraMode.Classic else Enum.CameraMode.LockFirstPerson
    player.CameraMinZoomDistance, player.CameraMaxZoomDistance = if socialPhase then 6 else 0.5, if socialPhase then 18 else 0.5
    local seen = {}
    for _, style in ipairs(value.publicStyles or {}) do
        local other = Players:GetPlayerByUserId(style.id)
        local head = other and other.Character and other.Character:FindFirstChild("Head")
        if head then
            seen[style.id] = true
            local b = boards[style.id]
            if not b then
                b = Instance.new("BillboardGui")
                b.Name, b.Size, b.StudsOffset, b.MaxDistance, b.Parent = "PublicCosmetic", UDim2.fromOffset(200, 66), Vector3.new(0, 3.5, 0), 40, gui
                local label = Instance.new("TextLabel")
                label.Name, label.Size, label.TextWrapped, label.TextSize, label.TextColor3, label.Parent = "Label", UDim2.fromScale(1, 1), true, 14, Color3.new(1, 1, 1), b
                boards[style.id] = b
            end
            b.Adornee = head
            b.Label.BackgroundColor3 = colors[style.card] or Color3.fromRGB(41, 47, 54)
            b.Label.Text = style.name .. (if style.title ~= "" then "\n" .. style.title else "")
                .. (if style.effect == "Celebration" and showEffects then "\n✦ ✧ ✦" elseif style.effect == "Wave" then "\nПривет! ◇" else "")
        end
    end
    for id, board in pairs(boards) do if not seen[id] then board:Destroy(); boards[id] = nil end end
    render()
end
remotes.PersonalUpdate.OnClientEvent:Connect(function(kind, value) if kind == "Snapshot" then snapshot(value) end end)
Input.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.J then toggle("Social")
    elseif input.KeyCode == Enum.KeyCode.K then toggle("Shop")
    elseif input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.H then panel.Visible = false end
end)
local ok, value = pcall(function() return remotes.GetState:InvokeServer() end)
if ok then snapshot(value) end
