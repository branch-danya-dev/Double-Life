local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local Prompts = game:GetService("ProximityPromptService")
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
local player = Players.LocalPlayer
player.CameraMode = Enum.CameraMode.LockFirstPerson
local remotes = RS:WaitForChild("DoubleLifeRemotes")
local update, action = remotes:WaitForChild("PersonalUpdate"), remotes:WaitForChild("CouncilAction")
local names = {Owner = "Владелец", Spy = "Шпион", CounterAgent = "Контрразведчик", Staff = "Персонал", Guest = "Гость", Waiting = "Ожидание"}
local phases = {Waiting = "Нужно 3 участника · свободный осмотр", Countdown = "Подготовка", Active = "Игра", Council = "Собрание · игра на паузе", Results = "Итоги"}
local goals = {
    Owner = "Сохраните досье. Пульт: E дверь, Z патруль, X проверка, C собрание.",
    Spy = "Вскройте окно, возьмите досье из сейфа и вынесите через главный выход.",
    CounterAgent = "Сохраните досье. Проверьте журнал в кабинете; оценивайте действия и улики.",
    Staff = "Сохраните досье и выполните доставку: стойка → сок → F у столика.",
    Guest = "Сохраните досье. Осмотрите 3 картины и получите сок к столику.",
    Waiting = "До старта можно осматривать картины и заказывать сок. Поздний вход — со следующего раунда.",
}
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.Parent = "DoubleLifeHUD", false, player:WaitForChild("PlayerGui")
local function frame(parent, name, size, position)
    local f = Instance.new("Frame")
    f.Name, f.Size, f.Position = name, size, position
    f.BackgroundColor3, f.BackgroundTransparency = Color3.fromRGB(19, 21, 28), 0.12
    f.Parent = parent
    return f
end
local function text(parent, name, value, y, height, size)
    local label = Instance.new("TextLabel")
    label.Name, label.Text = name, value
    label.Size, label.Position = UDim2.new(1, -24, 0, height), UDim2.fromOffset(12, y)
    label.BackgroundTransparency, label.TextWrapped = 1, true
    label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
    label.TextColor3, label.TextSize, label.Font = Color3.fromRGB(237, 233, 218), size or 14, Enum.Font.Gotham
    label.Parent = parent
    return label
end
local function button(parent, value, y, callback)
    local b = Instance.new("TextButton")
    b.Text, b.Size, b.Position = value, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, y)
    b.BackgroundColor3, b.TextColor3, b.TextSize = Color3.fromRGB(61, 81, 85), Color3.new(1, 1, 1), 14
    b.Font, b.Parent = Enum.Font.Gotham, parent
    b.Activated:Connect(callback)
    return b
end
local status = frame(gui, "StatusPanel", UDim2.fromOffset(390, 211), UDim2.fromOffset(14, 12))
local phaseLabel = text(status, "Phase", "DOUBLE LIFE · M2", 8, 22, 16)
local roleLabel = text(status, "Role", "Загрузка…", 32, 20)
local goalLabel = text(status, "Goal", "", 55, 48, 13)
local progressLabel = text(status, "Progress", "", 106, 34, 12)
local notice = text(status, "Notice", "H — правила · B — уронить улику", 146, 60, 12)
local visiblePrompts = {}
local function fitStatus()
    local compact = next(visiblePrompts) ~= nil
    status.Size = UDim2.fromOffset(390, if compact then 54 else 211)
    goalLabel.Visible, progressLabel.Visible, notice.Visible = not compact, not compact, not compact
end
Prompts.PromptShown:Connect(function(prompt)
    visiblePrompts[prompt] = true
    fitStatus()
end)
Prompts.PromptHidden:Connect(function(prompt)
    visiblePrompts[prompt] = nil
    fitStatus()
end)
local panel = frame(gui, "CouncilPanel", UDim2.new(0.85, 0, 0.82, 0), UDim2.fromScale(0.5, 0.5))
panel.AnchorPoint, panel.Visible = Vector2.new(0.5, 0.5), false
panel.BackgroundTransparency = 0.02
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize, constraint.Parent = Vector2.new(620, 600), panel
local scroll = Instance.new("ScrollingFrame")
scroll.Size, scroll.BackgroundTransparency, scroll.BorderSizePixel = UDim2.fromScale(1, 1), 1, 0
scroll.ScrollBarThickness, scroll.Parent = 6, panel
local last, showRules, attach, panelKey = nil, false, false, ""
local rules = "7 минут: шпион выносит досье через главный выход; остальные побеждают, если время истекло или шпион ушёл.\n\nРоль видите только вы. Общие занятия: 3 картины на западной стене, сок у столиков. Персонал: два действия у стойки, затем F у нужного столика. Никто не обязан ждать заказ на месте.\n\nВладелец после 30 с может один раз созвать собрание у пульта (C). На 25 с мир и игровой таймер замирают. Выберите другого участника. Один неизменяемый голос; пропуск — воздержание. Нужны голоса более половины всех оставшихся участников.\n\nДосмотр задерживает на 12 с и возвращает досье в сейф, если оно было. Никто не выбывает, роли не объявляются. Пломба у сейфа — только след события: подберите E, приложите к голосу или уроните B.\n\nОкно снаружи: выйдите на юг, обойдите дом слева и идите к кабинету. Пульт — в северном коридоре. E удерживается по подсказке. H — закрыть правила."
local function renderPanel()
    if not last then return end
    local r = last.round
    local key = r.phase .. ":" .. tostring(r.roundId) .. ":" .. tostring(showRules) .. ":" .. tostring(r.voted) .. ":" .. tostring(attach)
        .. ":" .. tostring(#r.protocol) .. ":" .. tostring(#r.members) .. ":" .. tostring(last.evidence ~= nil)
    panel.Visible = r.phase == "Council" or r.phase == "Results" or showRules
    status.Visible = not panel.Visible
    local timer = scroll:FindFirstChild("CouncilTime")
    if timer then timer.Text = "Собрание · осталось " .. r.remaining .. " с" end
    if key == panelKey then return end
    panelKey = key
    for _, child in ipairs(scroll:GetChildren()) do child:Destroy() end
    local y = 12
    local function line(value, height, size)
        text(scroll, "Line", value, y, height, size)
        y += height + 8
    end
    if r.phase == "Council" then
        text(scroll, "CouncilTime", "Собрание · осталось " .. r.remaining .. " с", y, 24, 18)
        y += 32
        line("Большинство всех участников: " .. (math.floor(#r.members / 2) + 1) .. ". Один голос, за себя нельзя. Не выбирать — воздержаться. Досмотр 12 с; никто не выбывает.", 56, 14)
        if r.participating and not r.voted then
            if last.evidence then
                button(scroll, if attach then "✓ Приложить: пломба · сейф, кабинет" else "Приложить улику к голосу", y, function()
                    attach = not attach; renderPanel()
                end)
                y += 38
            else attach = false end
            for _, member in ipairs(r.members) do
                if member.id ~= player.UserId then
                    local b = button(scroll, "Досмотреть: " .. member.name, y, function()
                        action:FireServer("Vote", r.roundId, member.id, attach)
                    end)
                    b.Modal = true
                    y += 38
                end
            end
        else line(if r.voted then "Ваш голос принят." else "Вы присоединитесь к следующему раунду.", 28) end
        line("Протокол: улика показывает место события, не виновника.", 36, 13)
        local lookup = {}
        for _, member in ipairs(r.members) do lookup[member.id] = member.name end
        for _, entry in ipairs(r.protocol) do
            line((lookup[entry.voter] or "Участник") .. " → " .. (lookup[entry.target] or "ушёл")
                .. (if entry.evidence then " · " .. entry.evidence.kind .. " · " .. entry.evidence.location else " · без улики"), 36, 13)
        end
    elseif r.phase == "Results" then
        local reasons = {Extraction = "Досье вынесено", Timeout = "Время истекло", SpyLeft = "Шпион покинул матч"}
        line(if r.result.winner == "Spy" then "Победа шпиона" else "Победа защитников", 28, 22)
        line(reasons[r.result.reason] or r.result.reason, 24)
        line("Ваши цели: картины " .. last.paintings .. "/3 · сок получен " .. last.refreshments .. " · доставки " .. math.floor(last.servicePoints / 10) .. " · очки " .. last.servicePoints, 48)
        line("Роли раскрываются только сейчас:", 24)
        for _, member in ipairs(r.result.roles) do line(member.name .. " — " .. names[member.role], 24) end
        line("Следующий раунд начнётся автоматически. Все очки и предметы относятся только к этому раунду.", 48)
    else
        line("DOUBLE LIFE · правила", 26, 20)
        line(rules, 390, 14)
    end
    -- Keeps the pointer usable in first person for Council/results/help.
    local caption = if r.phase == "Council" then "Дождитесь конца голосования (время вверху)"
        elseif r.phase == "Results" then "Следующий раунд начнётся автоматически" else "Закрыть правила [H]"
    local modal = button(scroll, caption, y, function()
        if r.phase ~= "Council" and r.phase ~= "Results" then showRules = false; renderPanel() end
    end)
    modal.Modal = true
    scroll.CanvasSize = UDim2.fromOffset(0, y + 44)
end
local function snapshot(value)
    local previous = last and last.round.roundId
    last = value
    if previous ~= value.round.roundId then attach = false; notice.Text = "H — правила · B — уронить улику" end
    local r = value.round
    local minutes, seconds = math.floor(r.remaining / 60), r.remaining % 60
    phaseLabel.Text = (phases[r.phase] or r.phase) .. " · " .. string.format("%d:%02d", minutes, seconds)
    roleLabel.Text = "Ваша роль: " .. names[value.role] .. (if value.hasDossier then " · досье у вас" else "")
    goalLabel.Text = goals[value.role]
    if r.search and r.search.id == player.UserId then goalLabel.Text = "Досмотр: осталось " .. r.search.remaining .. " с. Затем продолжайте свою цель." end
    progressLabel.Text = "Картины " .. value.paintings .. "/3 · сок " .. value.refreshments .. "/1 · доставки " .. math.floor(value.servicePoints / 10)
        .. (if value.evidence then "\nУлика: пломба · сейф, кабинет [B уронить]" else "\nH — правила · E/F — действия по подсказке")
    renderPanel()
end
update.OnClientEvent:Connect(function(kind, value)
    if kind == "Snapshot" then snapshot(value)
    elseif kind == "Notice" then notice.Text = value end
end)
Input.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.H then showRules = not showRules; renderPanel()
    elseif input.KeyCode == Enum.KeyCode.B and last then action:FireServer("DropEvidence", last.round.roundId) end
end)
local ok, state = pcall(function() return remotes:WaitForChild("GetState"):InvokeServer() end)
if ok then snapshot(state) end
