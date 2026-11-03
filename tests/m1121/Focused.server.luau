-- Focused reproduction after the full 1/2/3-client suite. No production changes.
assert(game:GetService('RunService'):IsStudio(),'Studio only')
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local modules=game.ServerScriptService.DoubleLifeServer
local driver=Instance.new('RemoteFunction'); driver.Name,driver.Parent='M6TestDriver',RS
local view=Instance.new('RemoteFunction'); view.Name,view.Parent='M112ContextView',RS
local rt=require(modules.Game).start({adapter=require(script.Parent.MemoryStore).new(require(modules.ProfileSchema).copy)})
rt.roles.random={NextInteger=function(_,_,high) return high end}
local function run()
    print('M1121 FOCUSED WAIT: start exactly two real clients')
    local untilTime=os.clock()+120
    repeat task.wait(0.2) until #Players:GetPlayers()==2 or os.clock()>untilTime
    assert(#Players:GetPlayers()==2,'two actual clients')
    for _,p in ipairs(Players:GetPlayers()) do
        repeat task.wait(0.1) until rt.prologue.records[p]
        driver:InvokeClient(p,{kind='Prologue',action='Lobby'})
        driver:InvokeClient(p,{kind='Queue',action='Cancel'})
    end
    require(script.Parent.Motion).run()
    print('M1121 FOCUSED PASS')
end
local ok,err=xpcall(run,debug.traceback)
if not ok then warn('M1121 FOCUSED FAIL',err) end
