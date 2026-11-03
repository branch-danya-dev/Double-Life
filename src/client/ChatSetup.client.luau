-- The project selects TextChatService before PlayerScripts are inserted.
-- Double Life uses fixed social signals; it does not offer a text chat channel.
local StarterGui = game:GetService("StarterGui")
task.spawn(function()
    for _ = 1, 10 do
        local ok = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) end)
        if ok then return end
        task.wait(0.5)
    end
    warn("Double Life: chat icon could not be hidden; chat configurations remain disabled")
end)
