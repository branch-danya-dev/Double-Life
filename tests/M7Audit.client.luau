local Players=game:GetService("Players")
local pg=Players.LocalPlayer:WaitForChild("PlayerGui")
local gui=pg:WaitForChild("MansionPresentation")
local client=Players.LocalPlayer.PlayerScripts:WaitForChild("DoubleLifeClient")
local UI=require(client:WaitForChild("Interface"))
task.wait(4)
local function check(ok,msg) assert(ok,msg); print("M7 CLIENT PASS",msg) end
local viewportDeadline=os.clock()+60
repeat task.wait(0.1) until (gui.AbsoluteSize.X>=200 and gui.AbsoluteSize.Y>=200) or os.clock()>viewportDeadline
check(gui.AbsoluteSize.X>=200 and gui.AbsoluteSize.Y>=200,"render surface initialized "..tostring(gui.AbsoluteSize))
check(gui.Menu.AbsoluteSize.Y>=44 and gui.Drop.AbsoluteSize.Y>=44,"touch menu/drop targets")
for _,panel in ipairs({gui.MansionMenu,gui.AtmosphereSettings}) do
    check(panel.AbsoluteSize.X<=gui.AbsoluteSize.X and panel.AbsoluteSize.Y<=gui.AbsoluteSize.Y,"menu/settings within usable viewport "..panel.Name)
    for _,child in ipairs(panel:GetChildren()) do
        if child:IsA("TextButton") then check(child.AbsoluteSize.Y>=44,"unscaled touch target "..child.Name) end
    end
end
check(not gui:GetAttribute("SoundEnabled") and gui:GetAttribute("MotionEnabled"),"quiet start / accessible motion setting")
UI.send("Rules"); task.wait(0.3)
local rules=pg.DoubleLifeHUD.CouncilPanel
check(rules.Visible,"shared menu opens rules")
local pager=pg.DoubleLifeHUD.CouncilPanelPager
check(pager.Visible and pager.Down.AbsoluteSize.Y>=44,"rules paging buttons available")
check(pager.AbsolutePosition.Y+pager.AbsoluteSize.Y<=pg.DoubleLifeHUD.AbsolutePosition.Y+pg.DoubleLifeHUD.AbsoluteSize.Y,"paging controls within viewport")
local view=gui.AbsoluteSize
check(rules.AbsoluteSize.X<=view.X and rules.AbsoluteSize.Y<=view.Y,"panel within viewport "..tostring(rules.AbsoluteSize).." / "..tostring(view))
UI.send("Shop"); task.wait(0.3)
check(pg.DoubleLifeSocial.SocialShopPanel.Visible and not rules.Visible,"one panel at a time")
UI.send("Close"); task.wait(0.3)
check(not pg.DoubleLifeSocial.SocialShopPanel.Visible and not rules.Visible,"back closes panels")
local sounds=game:GetService("SoundService")
local deadline=os.clock()+15
repeat task.wait(0.25) until (sounds.MansionCue.IsLoaded and sounds.MansionRoom.IsLoaded) or os.clock()>deadline
check(sounds.MansionCue.IsLoaded and sounds.MansionRoom.IsLoaded,"engine audio resources loaded")
print("M7 CLIENT SUITE PASS",Players.LocalPlayer.Name,view)
