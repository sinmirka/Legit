local players,vec=MOCK.players,MOCK.vec
local function fixture(id,x,z)
    local player={UserId=id,Name='Cycle'..id,DisplayName='Cycle'..id,Parent=players,Neutral=false,Team={}}
    local char=Instance.new('Model'); char.Parent=workspace; player.Character=char
    local hum=Instance.new('Humanoid'); hum.Health=100; char.Children.Humanoid=hum
    for _,name in ipairs({'Head','HumanoidRootPart'}) do
        local part=Instance.new('Part'); part.Position=vec(x,0,z); part.Parent=char
        part.AssemblyLinearVelocity=vec(0,0,0); char.Children[name]=part
    end
    return player,char,hum
end
local localFixture,character=fixture(1,0,0); players.LocalPlayer.Character=character
local near,nearChar=fixture(2,0,-10)
local middle,middleChar=fixture(3,0,20)
local far,farChar,farHum=fixture(4,0,-30)
players.list={players.LocalPlayer,far,middle,near} -- Deliberately unordered.
hookmetamethod=function() return function() return nil end end
getnamecallmethod=function() return 'Raycast' end
checkcaller=function() return false end
getcallingscript=function() return nil end
local app=assert(loadstring(SOURCES['main.lua']))()
local silent,s=app.SilentAim,app.Config.Silent
app.Library:SetOpen(false)
s.Enabled=true; s.Universal=true; s.Full360=true; s.AutoFire=true; s.CycleTargets=true
s.AutoFireMethod='Mouse'; s.AutoFireInterval=0.2
local hits={}
mouse1click=function()
    local target=silent.prepared.Target
    table.insert(hits,target.Player.UserId)
    local direction=silent:Redirect(nil,vec(0,0,0),vec(0,0,100))
    assert(direction and (direction.Unit-target.Position.Unit).Magnitude<1e-8,'input uses this cycle target')
end
silent:Step(1); silent:Step(1.1)
assert(#hits==1 and hits[1]==near.UserId,'starts nearest and respects interval')
silent:Step(1.21); silent:Step(1.42); silent:Step(1.63)
assert(hits[2]==middle.UserId and hits[3]==far.UserId and hits[4]==near.UserId,'near-middle-far then restart')
app.Engine.playerModes[middle.UserId]='Friend'; farHum.Health=0
silent:Step(1.84); assert(hits[5]==near.UserId,'invalid targets skipped without stalling cycle')
farHum.Health=100; app.Engine.playerModes[middle.UserId]=nil
silent:Reset(); hits={}
mouse1click=function() error('activation failed') end
silent:Step(2.1); assert(silent.prepared.Target.Player==near,'failed input retains nearest')
mouse1click=function() table.insert(hits,silent.prepared.Target.Player.UserId) end
silent:Step(2.31); assert(hits[1]==near.UserId,'failed attempt does not advance cycle')
s.CycleTargets=false; silent:Step(2.52); silent:Step(2.73)
assert(hits[2]==near.UserId and hits[3]==near.UserId,'toggle off restores normal priority')
s.CycleTargets=true; s.Full360=false; silent:Step(2.94); silent:Step(3.15)
assert(hits[4]==middle.UserId and hits[5]==middle.UserId,'cycle inactive without 360')
local function button(label)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,option in ipairs(section.options) do if option.class=='button' and option.text==label then return option end end
    end end
end
s.Full360=true
button('Save profile').callback(); app.Library.options.Silent_CycleTargets:SetState(false)
button('Load profile').callback(); assert(s.CycleTargets,'cycle option persists')
app:Unload()
print('PASS target cycling: nearest first, one target per input, repeat, departures/death/friends, errors, mode guards and profiles')
