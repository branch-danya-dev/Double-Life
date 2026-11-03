local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local UI = require(script.Parent.Interface)
local Prompts = game:GetService("ProximityPromptService")
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
local player = Players.LocalPlayer
player.CameraMode = Enum.CameraMode.LockFirstPerson
local remotes = RS:WaitForChild("DoubleLifeRemotes")
local update, action = remotes:WaitForChild("PersonalUpdate"), remotes:WaitForChild("CouncilAction")
local eventAction = remotes:WaitForChild("EventAction")
local profileAction = remotes:WaitForChild("ProfileAction")
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
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Parent = "DoubleLifeHUD", false, 6, player:WaitForChild("PlayerGui")
local function frame(parent, name, size, position)
    local f = Instance.new("Frame")
    f.Name, f.Size, f.Position = name, size, position
    f.BackgroundColor3, f.BackgroundTransparency = Color3.fromRGB(19, 21, 28), 0.12
    f.Parent = parent
    UI.decorate(f,false)
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
    b.Text, b.Size, b.Position = value, UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, y)
    b.BackgroundColor3, b.TextColor3, b.TextSize = Color3.fromRGB(61, 81, 85), Color3.new(1, 1, 1), 14
    b.Font, b.Parent = Enum.Font.Gotham, parent
    b.TextWrapped=true; UI.decorate(b,true)
    b.Activated:Connect(callback)
    return b
end
local status = frame(gui, "StatusPanel", UDim2.fromOffset(390, 211), UDim2.fromOffset(14, 12))
local phaseLabel = text(status, "Phase", "DOUBLE LIFE · ВЕЧЕРНИЙ ПРИЁМ", 8, 36, 14)
local roleLabel = text(status, "Role", "Загрузка…", 46, 32)
local goalLabel = text(status, "Goal", "", 86, 48, 13)
local progressLabel = text(status, "Progress", "", 138, 34, 12)
local notice = text(status, "Notice", "H — правила · B — уронить улику", 178, 60, 12)
local visiblePrompts = {}
local function fitStatus()
    local viewport=gui.AbsoluteSize
    local layout=UI.presentation.layout(viewport.X,viewport.Y)
    local compact = next(visiblePrompts) ~= nil or layout.compact
    status.Size = UDim2.fromOffset(layout.statusWidth, if compact then 86 else 241)
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
UI.bindPanel(panel)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize, constraint.Parent = Vector2.new(620, 600), panel
local scroll = Instance.new("ScrollingFrame")
scroll.Active=true
scroll.Size, scroll.BackgroundTransparency, scroll.BorderSizePixel = UDim2.fromScale(1, 1), 1, 0
scroll.ScrollBarThickness, scroll.Parent = 6, panel
UI.pager(gui,panel,scroll)
local banner = frame(gui, "ActivityBanner", UDim2.new(0.92, 0, 0, 94), UDim2.new(0.5, 0, 1, -12))
banner.AnchorPoint = Vector2.new(0.5, 1)
local bannerLimit = Instance.new("UISizeConstraint")
bannerLimit.MaxSize, bannerLimit.Parent = Vector2.new(570, 94), banner
local activityLabel = text(banner, "Activity", "", 8, 80, 14)
local last, showRules, showEvents, eventNotice, attach, panelKey = nil, false, false, "", false, ""
local showProfile = false
local hideResults = false
local profileMessages = {Ready = "Сохранено", Saving = "Сохраняем…", Loading = "Загружаем профиль…",
    Unavailable = "Сохранение недоступно; новые награды и покупки отключены.", Locked = "Профиль занят другой сессией; запись временно отключена.",
    Recovering = "Восстанавливаем профиль автоматически. Можно играть; постоянные награды и покупки пока отключены.",
    LostLease = "Сессия сохранения завершилась. Повторите вход; до этого прогресс отключён.", Malformed = "Профиль требует восстановления. Данные не изменены.",
    UnsupportedVersion = "Профиль создан более новой версией игры. Запись отключена.",
    Purchased = "Предмет куплен", Owned = "Этот предмет уже ваш", Equipped = "Выбор сохранён", LockedItem = "Предмет пока закрыт",
    InsufficientTokens = "Недостаточно жетонов", WrongSlot = "Неподходящий слот", NotForSale = "Открывается уровнем репутации",
    Pending = "Награда ожидает подтверждения сохранения", Awarded = "Награда сохранена", InsufficientActivity = "Недостаточно активности для постоянной награды",
    NotParticipant = "За этот раунд постоянной награды нет"}
local eventNames = {Relic = "Пропавшая реликвия", Music = "Музыка остановилась"}
local rules = "7 минут: шпион выносит досье через главный выход; остальные побеждают, если время истекло или ушли все шпионы. Досье возвращается в сейф через 60 с активного времени переноски, даже в движении.\n\nРоль видите только вы. Общие занятия: 3 картины на западной стене, сок у столиков. Персонал: два действия у стойки, затем F у нужного столика. Никто не обязан ждать заказ на месте.\n\nВладелец после 30 с может один раз созвать собрание у пульта (C). На 25 с мир и игровой таймер замирают. Выберите другого участника. Один неизменяемый голос; пропуск — воздержание. Нужны голоса более половины всех оставшихся участников.\n\nДосмотр задерживает на 12 с и возвращает досье в сейф, если оно было. Никто не выбывает, роли не объявляются. Пломба у сейфа — только след события: подберите E, приложите к голосу или уроните B.\n\nКабинет и пульт — этаж 2. Независимый путь: двор → западная лестница → архив → терраса → окно. Обратно: кнопка изнутри → любая лестница → приёмная → выход во дворе. E удерживается по подсказке. H — закрыть правила."
local function renderPanel()
    if not last then return end
    local r = last.round
    local p = last.profile or {status = "Loading"}
    local key = r.phase .. ":" .. tostring(r.roundId) .. ":" .. tostring(showRules) .. ":" .. tostring(r.voted) .. ":" .. tostring(attach)
        .. ":" .. tostring(#r.protocol) .. ":" .. tostring(#r.members) .. ":" .. tostring(last.evidence ~= nil)
        .. ":" .. tostring(showEvents) .. ":" .. eventNotice .. ":" .. last.activities.event.phase
        .. ":" .. tostring(last.activities.owner and last.activities.owner.reason)
        .. ":" .. tostring(showProfile) .. ":" .. p.status .. ":" .. tostring(p.revision) .. ":" .. tostring(p.requestResult)
        .. ":" .. tostring(p.reward and p.reward.reason)
        .. ":" .. tostring(p.retrying) .. ":" .. tostring(p.unconfirmed)
    panel.Visible = r.phase == "Council" or (r.phase == "Results" and not hideResults) or showRules or showEvents or showProfile
    local card = p.equipped and p.equipped.Card
    panel.BackgroundColor3 = if (showProfile or r.phase == "Results") and card == "TealCard" then Color3.fromRGB(23, 55, 57)
        elseif (showProfile or r.phase == "Results") and card == "AmberCard" then Color3.fromRGB(65, 47, 24) else UI.color("Ink")
    status.Visible = not panel.Visible
    banner.Visible = not panel.Visible
    local timer = scroll:FindFirstChild("CouncilTime")
    if timer then timer.Text = "Собрание · осталось " .. r.remaining .. " с" end
    local limits = scroll:FindFirstChild("EventLimit")
    local owner = last.activities.owner
    if limits and owner then limits.Text = "Осталось запусков: " .. owner.usesLeft .. "/2 · перерыв: " .. owner.cooldown .. " с" end
    if key == panelKey then return end
    panelKey = key
    for _, child in ipairs(scroll:GetChildren()) do child:Destroy() end
    local y = 12
    local function line(value, height, size)
        height=UI.textHeight(value,panel.AbsoluteSize.X-32,height,size)
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
                y += 50
            else attach = false end
            for _, member in ipairs(r.members) do
                if member.id ~= player.UserId then
                    local b = button(scroll, "Досмотреть: " .. member.name, y, function()
                        action:FireServer("Vote", r.roundId, member.id, attach)
                    end)
                    b.Modal = true
                    y += 50
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
    elseif showProfile then
        line("Профиль · репутация и Loadout", 28, 20)
        line(profileMessages[p.status] or "Сохранение временно недоступно. Повторите вход позже.", 48)
        if p.retrying then line("Автоматическое восстановление продолжается, до 3 минут.", 36)
        elseif p.status ~= "Ready" and p.status ~= "Saving" then line("Автоматические попытки завершены. Повторите вход позже.", 40) end
        if (p.unconfirmed or 0) > 0 then line("Не подтверждены операции прошлого подключения: " .. p.unconfirmed
            .. ". Они не повторялись после потери сессии. Проверьте баланс, коллекцию и историю.", 72) end
        if p.mode == "FakeMemory" then line("Тестовый профиль: данные живут только до закрытия тестового сервера.", 40, 12) end
        if p.reputationXp then
            line("Репутация " .. p.level .. "/10 · XP " .. p.reputationXp .. (if p.nextLevelXp then "/" .. p.nextLevelXp else " · максимум уровня")
                .. "\nЖетоны: " .. p.tokens .. " · матчей: " .. p.stats.played .. " · побед: " .. p.stats.wins, 55, 16)
            line("Мастерство ролей", 24, 17)
            for _, role in ipairs({"Spy", "CounterAgent", "Owner", "Staff", "Guest"}) do
                line(names[role] .. ": " .. p.mastery[role] .. "/5 · XP " .. p.roleXp[role]
                    .. " · матчей " .. p.stats.roles[role].played .. " · побед " .. p.stats.roles[role].wins, 32)
            end
            local achievements = {FirstRound = "Первый раунд", FirstWin = "Первая победа", AllRoles = "Все пять ролей"}
            local earned = {}
            for id, title in pairs(achievements) do if p.achievements[id] then table.insert(earned, title) end end
            line("Достижения: " .. (if #earned > 0 then table.concat(earned, ", ") else "впереди"), 44)
            line("Коллекция и снаряжение", 26, 17)
            line("Инструменты открываются общей репутацией. Выбор фиксируется при старте раунда; смена доступна только в ожидании и итогах.", 62)
            if p.requestResult then line("Последняя попытка: " .. (if p.requestResult == "Locked" then "предмет ещё не был открыт."
                else profileMessages[p.requestResult] or "предмет недоступен для этого действия."), 42) end
            for _, item in ipairs(p.catalog) do
                local equipped = p.equipped[item.slot] == item.id
                line(item.name .. " · " .. (names[item.slot] or item.slot) .. (if equipped then " · выбрано" elseif item.owned then " · в коллекции"
                    elseif item.price then " · " .. item.price .. " жетонов" else " · репутация " .. item.level), 32, 15)
                line(item.description, 54, 13)
                if p.status == "Ready" and not equipped then
                    if item.owned then
                        button(scroll, "Выбрать: " .. item.name, y, function() profileAction:FireServer("Equip", item.id, item.slot) end); y += 50
                    elseif item.price then
                        button(scroll, "Купить: " .. item.name, y, function() profileAction:FireServer("Buy", item.id) end); y += 50
                    end
                end
            end
            line("Последние матчи", 26, 17)
            for index = #p.history, 1, -1 do
                local h = p.history[index]
                line(names[h.role] .. " · " .. (if h.won then "победа" else "участие") .. " · +" .. h.xp .. " XP · +" .. h.tokens .. " жетонов", 32)
            end
        end
    elseif r.phase == "Results" then
        local reasons = {Extraction = "Досье вынесено", Timeout = "Время истекло", SpyLeft = "Все шпионы покинули матч"}
        line(if r.result.winner == "Spy" then "Победа шпионской команды" else "Победа защитников", 28, 22)
        line(reasons[r.result.reason] or r.result.reason, 24)
        line("Постоянный профиль · " .. (profileMessages[p.status] or "Сохранение недоступно"), 36)
        if p.equipped then
            for _, item in ipairs(p.catalog) do if item.id == p.equipped.Title then line("Титул: " .. item.name, 28, 16) end end
        end
        if p.reward and p.reward.reason == "Awarded" then
            local reward = p.reward
            line("+" .. reward.xp .. " XP репутации · +" .. reward.roleXp .. " XP роли · +" .. reward.tokens .. " жетонов\nРепутация "
                .. reward.beforeLevel .. " → " .. reward.level .. " · мастерство " .. reward.beforeMastery .. " → " .. reward.mastery, 60, 16)
            if #reward.unlocked > 0 then line("Открыто: " .. table.concat(reward.unlocked, ", "), 50) end
        else line(profileMessages[p.reward and p.reward.reason or "Unavailable"] or "Награда не подтверждена.", 44) end
        button(scroll, "Профиль, коллекция и Loadout [P]", y, function() showProfile = true; renderPanel() end); y += 50
        line("Ваши цели: картины " .. last.paintings .. "/3 · сок получен " .. last.refreshments .. " · доставки " .. math.floor(last.servicePoints / 10)
            .. " · очки доставки " .. last.servicePoints .. " · мероприятий " .. last.activities.event.score, 64)
        line("Роли раскрываются только сейчас:", 24)
        for _, member in ipairs(r.result.roles) do line(member.name .. " — " .. names[member.role], 24) end
        line("Следующий раунд начнётся автоматически. Сессионные очки сбросятся; подтверждённый прогресс профиля сохранён.", 48)
    elseif showEvents and owner then
        line("Выберите мероприятие", 28, 20)
        text(scroll, "EventLimit", "Осталось запусков: " .. owner.usesLeft .. "/2 · перерыв: " .. owner.cooldown .. " с", y, 28)
        y += 36
        line("Поиск: 60 с, реликвию нужно принести на постамент. Музыка: три пары двигайся/замри на цветной площадке. Участие добровольное для всех.", 80)
        if owner.reason then line(owner.reason, 52)
        else
            for _, kind in ipairs({"Relic", "Music"}) do
                button(scroll, eventNames[kind], y, function()
                    eventAction:FireServer("Start", r.roundId, kind)
                end)
                y += 50
            end
        end
        if eventNotice ~= "" then line(eventNotice, 60) end
    else
        line("DOUBLE LIFE · правила", 26, 20)
        line("Ваша цель: "..goals[last.role],72,15)
        line(rules, 390, 14)
        line("Мероприятия: владелец выбирает у синего пульта в бальном зале на этаже 1 (2 за раунд, перерыв 55 с). Любой может найти реликвию и отнести на постамент (G — положить) или двигаться/замирать на площадке. Уходить с площадки можно в любой момент.\n\nГостевые занятия иногда приводят к проверке охраны или короткому сбою света. Подсветка путей сохраняется. В ожидании следуйте трём шагам практики внизу экрана.", 210, 14)
    end
    -- Keeps the pointer usable in first person for Council/results/help.
    local caption = if showProfile then "Назад [P]" elseif r.phase == "Council" then "Дождитесь конца голосования (время вверху)"
        elseif r.phase == "Results" then "Свернуть итоги [H] · следующий раунд автоматически" else "Закрыть [H]"
    local modal = button(scroll, caption, y, function()
        if showProfile then showProfile = false; renderPanel()
        elseif r.phase == "Results" then hideResults = true; renderPanel()
        elseif r.phase ~= "Council" and r.phase ~= "Results" then showRules, showEvents = false, false; renderPanel() end
    end)
    modal.Modal = true
    scroll.CanvasSize = UDim2.fromOffset(0, y + 56)
    UI.focus(panel)
end
local function snapshot(value)
    local previous = last and last.round.roundId
    last = value
    if previous ~= value.round.roundId then attach, showEvents, eventNotice = false, false, ""; notice.Text = "H — правила · B — уронить улику" end
    if value.round.phase ~= "Results" then hideResults = false end
    local r = value.round
    if r.phase ~= "Waiting" and r.phase ~= "Results" then showProfile = false end
    if r.phase ~= "Active" or not value.activities.owner then showEvents = false end
    local minutes, seconds = math.floor(r.remaining / 60), r.remaining % 60
    phaseLabel.Text = (phases[r.phase] or r.phase) .. " · " .. string.format("%d:%02d", minutes, seconds)
    roleLabel.Text = "Ваша роль: " .. names[value.role] .. (if value.hasDossier then " · досье у вас" else "")
    goalLabel.Text = goals[value.role]
    if r.search and r.search.id == player.UserId then goalLabel.Text = "Досмотр: осталось " .. r.search.remaining .. " с. Затем продолжайте свою цель." end
    progressLabel.Text = "Картины " .. value.paintings .. "/3 · сок " .. value.refreshments .. "/1 · доставки " .. math.floor(value.servicePoints / 10)
        .. (if value.evidence then "\nУлика: пломба · сейф, кабинет [B уронить]" else "\nH — правила · E/F — действия по подсказке")
    local a, lines = value.activities, {}
    local e = a.event
    if a.practice then
        local steps = {"1/3 Осмотрите картину у западной стены.", "2/3 Закажите сок у зелёного столика и дождитесь NPC.",
            "3/3 Позовите охрану колокольчиком у восточной стены.", "Практика завершена! Можно повторить; очки не начисляются."}
        table.insert(lines, "Практика · " .. a.practice.remaining .. " с · " .. steps[a.practice.step] .. "\nP — профиль и снаряжение")
    elseif e.phase == "Announcing" then table.insert(lines, eventNames[e.kind] .. " через " .. e.remaining .. " с · участие добровольное")
    elseif e.phase == "Running" then
        local instruction = if e.kind == "Relic" then (if e.hasRelic then "Постамент: бальный зал, этаж 1 · G положить" else "Реликвия: галерея, читальня или архив")
            else (if e.beat == "Move" then "ДВИГАЙСЯ" else "ЗАМРИ") .. " на площадке · " .. e.beatIndex .. "/3 · зачтено " .. e.passes
        table.insert(lines, eventNames[e.kind] .. " · " .. e.remaining .. " с\n" .. instruction)
    elseif e.phase == "Finished" then
        table.insert(lines, (if e.cancelled then "Мероприятие прервано" else "Мероприятие завершено · вам +" .. e.reward) .. " · очки мероприятий: " .. e.score)
    else table.insert(lines, "Очки мероприятий: " .. e.score .. " · H правила · G положить реликвию") end
    if a.incident then
        table.insert(lines, (if a.incident.kind == "Blackout" then "Сбой света · пути подсвечены" else "Внеплановая проверка охраны") .. " · " .. a.incident.remaining .. " с")
    end
    activityLabel.Text = table.concat(lines, "\n")
    if value.profile and value.profile.status ~= "Ready" and value.profile.status ~= "Saving" and value.profile.status ~= "Loading" then
        notice.Text = "Сохранение недоступно: игра продолжается без постоянных наград и покупок."
    end
    renderPanel()
end
update.OnClientEvent:Connect(function(kind, value)
    if kind == "Snapshot" then snapshot(value)
    elseif kind == "Notice" then notice.Text = value end
    if kind == "EventMenu" then showEvents, showRules, eventNotice = true, false, ""; renderPanel()
    elseif kind == "EventNotice" then eventNotice = value; notice.Text = value; renderPanel() end
end)
Input.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.H then
        if showProfile then showProfile = false elseif showEvents then showEvents = false
        elseif last and last.round.phase == "Results" then hideResults = not hideResults
        else showRules = not showRules end
        renderPanel()
    elseif input.KeyCode == Enum.KeyCode.P and last and (last.round.phase == "Waiting" or last.round.phase == "Results") then
        showProfile, showRules, showEvents = not showProfile, false, false; renderPanel()
    elseif input.KeyCode == Enum.KeyCode.B and last then action:FireServer("DropEvidence", last.round.roundId)
    elseif input.KeyCode == Enum.KeyCode.G and last then eventAction:FireServer("DropRelic", last.round.roundId) end
end)
UI.action:Connect(function(command)
    if command=="Rules" then showRules,showProfile,showEvents=true,false,false
    elseif command=="Profile" and last and (last.round.phase=="Waiting" or last.round.phase=="Results") then
        showProfile,showRules,showEvents=true,false,false
    elseif command=="Close" or command=="Social" or command=="Shop" then
        showRules,showProfile,showEvents=false,false,false; hideResults=true
    else return end
    renderPanel()
end)
player.PlayerGui:GetAttributeChangedSignal("MansionPanel"):Connect(function()
    if player.PlayerGui:GetAttribute("MansionPanel")~="CouncilPanel" then
        showRules,showProfile,showEvents=false,false,false; hideResults=true; renderPanel()
    end
end)
local function resize()
    local viewport=gui.AbsoluteSize
    local layout=UI.presentation.layout(viewport.X,viewport.Y)
    panel.Size=UDim2.fromOffset(layout.panelWidth,layout.panelHeight)
    banner.Size=UDim2.new(1,-28,0,if layout.compact then 76 else 94)
    banner.Position=UDim2.new(0.5,0,1,if layout.compact then -10 else -12)
    activityLabel.TextSize=if layout.compact then 12 else 14
    activityLabel.Size=UDim2.new(1,-24,1,-16)
    panelKey=""; fitStatus(); renderPanel()
end
UI.watchViewport(gui,resize)
local ok, state = pcall(function() return remotes:WaitForChild("GetState"):InvokeServer() end)
if ok then snapshot(state) end
