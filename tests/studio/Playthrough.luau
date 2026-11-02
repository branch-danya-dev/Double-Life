return function(runtime, driver, eventually, check)
    local Players = game:GetService("Players")
    eventually(function() return #Players:GetPlayers() >= 2 end, 180, "playthrough requires 2+ clients")
    task.wait(10) -- Let all clients from the same Studio launch finish joining.
    local roster = {}
    for _, player in ipairs(Players:GetPlayers()) do roster[runtime.roles:get(player)] = player end
    local spy, owner, staff, guest = roster.Spy, roster.Owner, roster.Staff, roster.Guest
    assert(spy and owner, "owner and spy required")
    local function use(player, position, name, action)
        check(driver:InvokeClient(player, position, name, action), "prompt input: " .. name .. " / " .. action)
    end
    local function hasDossier()
        return spy.Backpack:FindFirstChild("DoubleLifeDossier") or spy.Character:FindFirstChild("DoubleLifeDossier")
    end
    -- Check authority through real client input, not direct service mutation.
    use(spy, Vector3.new(0, 4, 30), "OwnerAccessConsole", "Сменить зону патруля")
    check(runtime.guard.policy.zone == "Corridor", "spy rejected at owner console")
    use(owner, Vector3.new(0, 4, 36), "OwnerAccessConsole", "Сменить зону патруля")
    check(runtime.guard.policy.zone == "Foyer", "owner selects one zone")
    use(owner, Vector3.new(0, 4, 36), "OwnerAccessConsole", "Сменить зону патруля")
    check(runtime.guard.policy.zone == "Foyer", "owner command spam rejected")
    if guest then
        use(guest, Vector3.new(-8, 4, 22), "ServicePoint2", "Заказать сок сюда")
        check(runtime.requests.ledger.requests[guest.UserId] ~= nil, "honest guest request accepted")
        runtime.requests:remove(guest) -- isolated fixture cleanup, not gameplay completion.
    end
    eventually(function() return runtime.guard.policy.state == "Patrol" and os.clock() >= runtime.guard.policy.nextReaction end, 50, "guard not ready")
    use(spy, Vector3.new(17, 4, -10), "ServicePoint1", "Заказать сок сюда")
    local request = runtime.requests.ledger.requests[spy.UserId]
    check(request ~= nil, "spy uses same public request")
    use(spy, Vector3.new(-12, 4, 18), "ServicePoint2", "Заказать сок сюда")
    check(runtime.requests.ledger.requests[spy.UserId] == request, "duplicate public request rejected")
    if staff then
        use(staff, Vector3.new(-15, 4, 19), "ServicePantry", "Принять заказ / взять сок")
        check(request.executor == staff.UserId and request.state == "Accepted", "staff takes request")
        use(staff, Vector3.new(-15, 4, 19), "ServicePantry", "Принять заказ / взять сок")
        check(request.state == "Carrying", "staff takes physical supplies")
    end
    eventually(function() return runtime.guard.policy.state == "Investigate" end, 15, "service did not divert guard")
    -- Test players are positioned for repeatability; NPCs still use real navigation.
    use(spy, Vector3.new(-22, 4, 58), "StudyWindow", "Открыть окно")
    check(not runtime.world.studyWindow.CanCollide, "window opens through server handler")
    local beforeTheft = driver:InvokeClient(owner, "NoticeCount")
    use(spy, Vector3.new(0, 4, 61), "DocumentSafe", "Осмотреть")
    check(hasDossier(), "dossier stolen through prompt")
    local afterTheft = driver:InvokeClient(owner, "NoticeCount")
    check(beforeTheft.notices == afterTheft.notices and beforeTheft.results == afterTheft.results, "theft sends no automatic owner alarm")
    if staff then
        use(staff, Vector3.new(20, 4, -7), "ServicePoint1", "Доставить сок")
        check(request.state == "Delivered" and runtime.requests.ledger.scores[staff.UserId] == 10, "staff delivery earns session points")
    end
    use(spy, Vector3.new(0, 4, -24), "EstateExit", "Покинуть особняк")
    check(runtime.state.finished, "spy extraction completes M0 objective")
    eventually(function() return not runtime.state.finished end, 10, "mission did not reset")
    check(not hasDossier(), "dossier resets for next test")
    if staff then
        eventually(function() return os.clock() >= runtime.requests.ledger.cooldowns[spy.UserId] end, 50, "request cooldown did not elapse")
        use(spy, Vector3.new(17, 4, -10), "ServicePoint1", "Заказать сок сюда")
        local abandoned = assert(runtime.requests.ledger.requests[spy.UserId])
        use(staff, Vector3.new(-15, 4, 19), "ServicePantry", "Принять заказ / взять сок")
        use(staff, Vector3.new(-15, 4, 19), "ServicePantry", "Принять заказ / взять сок")
        staff:Kick("M1 fixture: staff disconnect recovery")
        eventually(function() return abandoned.executor ~= staff.UserId end, 8, "staff disconnect did not release request")
        eventually(function() return abandoned.state == "Delivered" end, 35, "NPC did not complete abandoned request")
        check(true, "staff disconnect recovered with physical NPC delivery")
    end
    eventually(function() return runtime.guard.policy.state == "Patrol" end, 40, "guard did not return before owner disconnect")
    local initial = runtime.guard.mover.root.Position
    owner:Kick("M1 fixture: owner absence")
    eventually(function() return (runtime.guard.mover.root.Position - initial).Magnitude > 3 end, 12, "owner disconnect stopped guard")
    check(true, "owner disconnect does not stop guard")
    print("M1 PLAYTHROUGH PASS", #Players:GetPlayers(), "clients")
end
