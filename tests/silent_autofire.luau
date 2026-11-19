local players,vec=MOCK.players,MOCK.vec
local function fixture(id,x,z)
    local player={UserId=id,Name='Auto'..id,DisplayName='Auto'..id,Parent=players,Neutral=false,Team={}}
    local char=Instance.new('Model'); char.Parent=workspace; player.Character=char
    local hum=Instance.new('Humanoid'); hum.Health=100; char.Children.Humanoid=hum
    for _,name in ipairs({'Head','HumanoidRootPart'}) do
        local part=Instance.new('Part'); part.Position=vec(x,0,z); part.Parent=char
        part.AssemblyLinearVelocity=vec(0,0,0); char.Children[name]=part
    end
    return player,char,hum
end
local localFixture,character=fixture(1,0,0)
players.LocalPlayer.Character=character
local enemy,enemyChar,enemyHum=fixture(2,6,30)
players.list={players.LocalPlayer,enemy}
hookmetamethod=function() return function() return nil end end
getnamecallmethod=function() return 'Raycast' end
checkcaller=function() return false end
getcallingscript=function() return nil end
local clicks,shots,releases=0,0,0
mouse1click=function() clicks+=1 end
local app=assert(loadstring(SOURCES['main.lua']))()
local silent,s=app.SilentAim,app.Config.Silent
app.Library:SetOpen(false); s.Enabled=true; s.Universal=true
local tool=Instance.new('Tool'); tool.Parent=character; tool.Enabled=true; tool.Name='Any gun'
character.Children.Tool=tool
function tool:Activate()
    assert(silent.prepared.Target.Player==enemy,'target is prepared before activation')
    shots+=1
end
function tool:Deactivate() releases+=1 end
silent:Step(0); assert(shots==0 and clicks==0,'default never fires')
s.AutoFire=true; s.AutoFireInterval=0.2
silent:Step(1); assert(shots==1 and clicks==0,'Auto uses equipped unknown Tool')
silent:Step(1.1); assert(shots==1 and releases==1,'pulse released and interval respected')
silent:Step(1.21); assert(shots==2,'next permitted pulse')
s.Radius=1; silent:Step(1.5); assert(shots==2 and releases==2,'target leaves FOV: release without firing')
s.Radius=160; workspace.Hit={Instance={IsDescendantOf=function() return false end}}
silent:Step(2); assert(shots==2,'wall blocks auto fire'); workspace.Hit=nil
enemy.Team=players.LocalPlayer.Team; s.TeamCheck=true; silent:Step(3)
assert(shots==2,'teammates excluded'); s.TeamCheck=false
app.Engine.playerModes[enemy.UserId]='Friend'; silent:Step(4)
assert(shots==2,'friends excluded'); app.Engine.playerModes[enemy.UserId]=nil
enemyHum.Health=15; enemyHum.PlatformStand=true; silent:Step(5)
assert(shots==2,'downed excluded'); enemyHum.Health=100; enemyHum.PlatformStand=false
app.Library:SetOpen(true); silent:Step(6); assert(shots==2,'menu pause')
app.Library:SetOpen(false); app.Engine.focused=false; silent:Step(7); assert(shots==2,'focus pause')
app.Engine.focused=true
local getFocused=MOCK.services.UserInputService.GetFocusedTextBox
MOCK.services.UserInputService.GetFocusedTextBox=function() return {} end
silent:Step(8); assert(shots==2,'text input pause')
MOCK.services.UserInputService.GetFocusedTextBox=getFocused
tool.Enabled=false; silent:Step(9); assert(shots==2,'disabled Tool cannot be fired')
tool.Enabled=true; s.HitChance=0; silent:Step(10); assert(shots==2,'zero hit chance does not spend shots')
s.HitChance=100; s.AutoFireMethod='Mouse'; silent:Step(11)
assert(shots==2 and clicks==1,'explicit Mouse input with Tool equipped')
character.Children.Tool=nil; s.AutoFireMethod='Auto'; silent:Step(12)
assert(clicks==2,'Auto supports weapons without Roblox Tool')
mouse1click=nil; silent:Step(13)
assert(silent.AutoFireStatus:find('mouse1click',1,true),'missing input API reported')
mouse1click=function() error('input failed') end; silent:Step(14)
assert(silent.AutoFireStatus=='Activation failed' and silent.prepared,'input errors isolated from targeting')
mouse1click=function() clicks+=1 end
character.Children.Tool=tool; s.AutoFireMethod='Tool'
local activate=tool.Activate
tool.Activate=function() error('tool failed') end; silent:Step(15)
assert(silent.AutoFireStatus=='Activation failed' and not silent.autoFireTool,'failed activation released')
tool.Activate=activate; silent:Step(16); assert(shots==3 and silent.autoFireTool==tool,'resume Tool pulses')
app.Library.options.Silent_AutoFire:SetState(false)
assert(not silent.autoFireTool and releases==4,'toggle off releases immediately')
silent:Step(17); assert(shots==3,'off stops all input')
local function button(label)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,option in ipairs(section.options) do if option.class=='button' and option.text==label then return option end end
    end end
end
app.Library.options.Silent_AutoFire:SetState(true)
app.Library.options.Silent_AutoFireInterval:SetValue(0.3)
assert(not app.Library.options.Silent_AutoFireMethod,'input method is automatic in compact UI')
s.AutoFireMethod='Auto'
button('Save profile').callback()
app.Library.options.Silent_AutoFire:SetState(false)
button('Load profile').callback()
assert(s.AutoFire and s.AutoFireInterval==0.3 and s.AutoFireMethod=='Auto','autofire profile roundtrip')
s.AutoFireMethod='Tool'; silent:Step(18)
assert(silent.autoFireTool==tool,'Tool pulse active before unload: '..tostring(silent.AutoFireStatus))
local before,beforeRelease=shots,releases; app:Unload()
assert(not silent.autoFireTool and releases==beforeRelease+1,'unload releases owned Tool activation')
silent:Step(19); assert(shots==before,'no firing after unload')
print('PASS silent auto fire: target filters, Tool and mouse, cadence, input pauses, errors, profiles, release on disable and unload')
