local app=assert(loadstring(SOURCES['main.lua']))()
local aura,s=app.MeleeAura,app.Config.Melee
local players=MOCK.players
local vec=MOCK.vec
local function player(id,x)
    local p={UserId=id,Name='Melee'..id,DisplayName='Melee'..id,Parent=players,Neutral=false,Team={}}
    local char=Instance.new('Model'); char.Parent=workspace; p.Character=char
    for _,name in ipairs({'Head','Torso','HumanoidRootPart'}) do
        local part=Instance.new('Part'); part.Name=name; part.Position=vec(x,0,0); part.Parent=char
        char.Children[name]=part
    end
    local hum=Instance.new('Humanoid'); hum.Health=100; char.Children.Humanoid=hum
    return p,char,hum
end
local localFixture,character=player(1,0)
players.LocalPlayer.Character=character
local near,nearChar,nearHum=player(2,5)
local far,farChar,farHum=player(3,8)
players.list={players.LocalPlayer,far,near}
local tool=Instance.new('Tool'); tool.Name='Fists'; tool.Parent=character; tool.Enabled=true
character.Children.Tool=tool
local attacks=0
function tool:Activate() attacks+=1; self.Activated:Fire() end
local caller=Instance.new('LocalScript'); caller.Name='MeleeScript'; caller.Parent=tool
local callingScript=caller
local isExecutor=false
local method='Raycast'
local installed,originalCalls=0,0
local intercepted,lastArgs,lastReceiver
hookmetamethod=function(_,name,fn)
    assert(name=='__namecall')
    installed+=1; intercepted=fn
    return function(receiver,...)
        originalCalls+=1; lastReceiver=receiver; lastArgs=table.pack(...)
        return 'original-result','second-result'
    end
end
getnamecallmethod=function() return method end
checkcaller=function() return isExecutor end
getcallingscript=function() return callingScript end
newcclosure=function(fn) return fn end
local root=character.Children.HumanoidRootPart
local original=vec(0,1,0)
local params={FilterDescendantsInstances={character}}
local function cast()
    local a,b=intercepted(workspace,root.Position,original,params,nil,'extra')
    assert(a=='original-result' and b=='second-result','original return values')
    assert(lastReceiver==workspace and lastArgs.n==5 and lastArgs[3]==params and lastArgs[5]=='extra','preserve receiver, params and nil varargs')
    return lastArgs[2]
end
local function unchanged(message) assert(cast()==original,message) end
app.Library:SetOpen(false)
aura:Step(0)
assert(installed==0 and attacks==0,'disabled must not hook or attack')
s.Enabled=true
aura:Step(0)
assert(installed==1 and attacks==1 and aura.target.Player==near,'auto attack closest player')
local redirected=cast()
assert(redirected.X>5 and redirected.Y==0,'redirect a real hitbox ray toward target')
aura:Step(0.1); assert(attacks==1,'attack interval')
aura:Step(0.5); assert(attacks==2,'next attack')
isExecutor=true; unchanged('executor visibility rays bypass hook'); isExecutor=false
method='FindPartOnRay'; unchanged('other methods unchanged'); method='Raycast'
callingScript=Instance.new('LocalScript'); callingScript.Name='Camera'
unchanged('unrelated game rays unchanged')
callingScript.Name='RaycastHitboxV4'
assert(cast()~=original,'shared melee hitbox module supported')
callingScript=caller
intercepted(workspace,root.Position,vec(0,1000,0),params)
assert(lastArgs[2].Y==1000,'long gun rays ignored')
intercepted(workspace,vec(100,0,0),original,params)
assert(lastArgs[2]==original,'distant origins ignored')
intercepted({},root.Position,original,params)
assert(lastArgs[2]==original,'non-workspace receiver ignored')
intercepted(workspace,'bad origin',original,params)
assert(lastArgs[1]=='bad origin','invalid arguments forwarded')
intercepted(workspace,root.Position,vec(0/0,0,0),params)
assert(lastArgs[2].X~=lastArgs[2].X,'NaN forwarded without hook errors')
s.Enabled=false; unchanged('disable effective before next heartbeat'); s.Enabled=true
nearHum.Health=0; unchanged('death effective before next heartbeat'); nearHum.Health=100
nearChar.Children.Head.Position=vec(30,0,0); unchanged('out of reach before next heartbeat')
nearChar.Children.Head.Position=vec(5,0,0)
nearChar.Children.ForceField=Instance.new('ForceField'); aura:Step(0.6)
assert(aura.target and aura.target.Player==far,'ForceField refreshes target selection on Heartbeat')
nearChar.Children.ForceField=nil
aura:Step(0.7)
workspace.Hit={Instance=Instance.new('Part')}
workspace.Hit.Instance.IsDescendantOf=function() return false end
aura:Step(1); assert(not aura.target,'walls block selection')
unchanged('new wall invalidates prepared target on Heartbeat')
s.WallCheck=false; aura:Step(1); assert(aura.target,'wall check configurable')
s.WallCheck=true; workspace.Hit=nil
s.TeamCheck=true; near.Team=players.LocalPlayer.Team
aura:Step(2); assert(aura.target.Player==far,'team filter')
s.TeamCheck=false; s.SkipFriends=true; app.Engine.friends[near]=true
aura:Step(3); assert(aura.target.Player==far,'friend filter')
s.SkipFriends=false; s.Priority='Lowest health'; farHum.Health=20
aura:Step(4); assert(aura.target.Player==far,'health priority')
s.MinHealth=21; aura:Step(5); assert(aura.target.Player==near,'minimum health')
s.Part='UpperTorso'; aura:Step(6); assert(aura.target.Part==nearChar.Children.Torso,'R6 torso fallback')
s.Part='Head'; s.Priority='Distance'; s.MinHealth=1
s.AutoAttack=false; local before=attacks
aura:Step(7); assert(attacks==before,'manual mode does not activate tool')
aura.swingUntil=0; unchanged('manual mode needs swing')
tool.Activated:Fire(); assert(cast()~=original,'manual activation opens raycast window')
aura.swingUntil=os.clock()-1; unchanged('expired swing window')
s.PauseMenu=true; app.Library:SetOpen(true); aura:Step(8)
assert(not aura.target,'menu pause')
app.Library:SetOpen(false); app.Engine.focused=false; aura:Step(9)
assert(not aura.target,'focus pause'); app.Engine.focused=true
local getFocused=MOCK.services.UserInputService.GetFocusedTextBox
MOCK.services.UserInputService.GetFocusedTextBox=function() return {} end
aura:Step(10); assert(not aura.target,'typing pause')
MOCK.services.UserInputService.GetFocusedTextBox=getFocused
tool.Name='Pistol'; aura:Step(11); assert(not aura.target and not aura.tool,'guns never activate aura')
tool.Name='Fists'; tool.Enabled=false; aura:Step(12); assert(not aura.target,'disabled tool')
tool.Enabled=true; aura:Step(13)
tool.Name='Golfclub'; aura:Step(13.5)
assert(aura.tool==tool and aura.target,'observed Criminality Golfclub is recognized as melee')
local roster=getmetatable(aura).WeaponNames
for _,name in ipairs(roster) do
    tool.Name=name; aura:Step(13.6)
    assert(aura.tool==tool and aura.target,'wiki melee recognized: '..name)
end
for _,name in ipairs({'Metal-Bat','Golfclub','fire_axe',"Slayer's II",'Cash Cane','Military Machete'}) do
    tool.Name=name; assert(aura:IsMeleeTool(tool),'name variant recognized: '..name)
end
tool.Name='AK-47'; assert(not aura:IsMeleeTool(tool),'unrelated gun rejected')
tool.Name='Katana Gun'; assert(not aura:IsMeleeTool(tool),'no substring weapon matches')
for _,name in ipairs({'__ZombieFists1','__ZombieFists2','__ZombieFists123','__ZombieFists',
    '__Fists1','__InfectedFists3','__X-Fist2','__zOmBiEfIsTs42'}) do
    tool.Name=name; aura:Step(13.61)
    assert(aura:IsMeleeTool(tool) and aura.tool==tool and aura.target,'numbered fists usable by aura: '..name)
end
for _,name in ipairs({'GunFists','__ZombieFists1Gun','__ZombieFistsLauncher','Pistol2'}) do
    tool.Name=name; assert(not aura:IsMeleeTool(tool),'fist-family match is anchored: '..name)
end
tool.Name='Custom melee skin'
tool.Children.Melee=Instance.new('ModuleScript'); tool.Children.AnimsFolder=Instance.new('Folder')
tool.Children.WeaponHandle=Instance.new('Part')
assert(aura:IsMeleeTool(tool),'renamed melee recognized by observed tool layout')
tool.Children.Melee=Instance.new('Folder')
assert(not aura:IsMeleeTool(tool),'non-module named Melee is not enough')
tool.Children.Melee=nil; tool.Children.AnimsFolder=nil; tool.Children.WeaponHandle=nil
tool.Name='Fists'
assert(s.SkipDowned,'downed filter enabled by default')
local replicated=MOCK.services.ReplicatedStorage
local statsRoot=Instance.new('Folder'); statsRoot.Parent=replicated; replicated.Children.CharStats=statsRoot
local function downedFlag(player)
    local stats=Instance.new('Folder'); stats.Parent=statsRoot; statsRoot.Children[player.Name]=stats
    local flag=Instance.new('BoolValue'); flag.Parent=stats; flag.Value=false; stats.Children.Downed=flag
    return flag
end
local nearDowned,farDowned=downedFlag(near),downedFlag(far)
aura:Step(13.7); tool.Activated:Fire()
nearDowned.Value=true
unchanged('cached Downed BoolValue blocks a ray immediately, without Instance calls')
aura:Step(13.8); assert(aura.target and aura.target.Player==far,'downed nearest target skipped')
farDowned.Value=true; local beforeDowned=attacks; s.AutoAttack=true
aura:Step(13.9)
assert(not aura.target and attacks==beforeDowned,'no auto attack when all targets are downed')
nearDowned.Value=false; farDowned.Value=false; s.AutoAttack=false
nearHum.State=Enum.HumanoidStateType.Ragdoll
aura:Step(13.91); assert(aura.target.Player==far,'ragdoll skipped')
nearHum.State=Enum.HumanoidStateType.FallingDown
aura:Step(13.92); assert(aura.target.Player==far,'falling-down state skipped')
nearHum.State=Enum.HumanoidStateType.Running; nearHum.PlatformStand=true
aura:Step(13.93); assert(aura.target.Player==far,'platform-standing target skipped')
nearHum.PlatformStand=false; nearChar.Attributes={Downed=true}
aura:Step(13.94); assert(aura.target.Player==far,'character Downed attribute skipped')
nearChar.Attributes.Downed=false; nearDowned.Value=true; s.SkipDowned=false
aura:Step(13.95); assert(aura.target.Player==near,'filter may be explicitly disabled')
s.SkipDowned=true; nearDowned.Value=false
nearHum.Health=5; aura:Step(13.96)
assert(aura.target.Player==near,'low health alone is not treated as downed')
nearHum.Health=100; statsRoot.Children[near.Name]=nil
aura:Step(13.97); assert(aura.target.Player==near,'missing game stats do not crash or exclude healthy rigs')
character.Children.Humanoid.Health=0; aura:Step(14); assert(not aura.target,'local death')
character.Children.Humanoid.Health=100
-- Real UI/profile callbacks include all new settings and clear pending swing state.
local function button(text)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,option in ipairs(section.options) do if option.class=='button' and option.text==text then return option end end
    end end
end
local options=app.Library.options
options.Melee_Enabled:SetState(true); options.Melee_Range:SetValue(15)
options.Melee_SkipDowned:SetState(false)
options.Melee_Part:Select('UpperTorso'); button('Save profile').callback()
options.Melee_Range:SetValue(5); options.Melee_Enabled:SetState(false)
button('Load profile').callback()
assert(s.Range==15 and s.Enabled and s.Part=='UpperTorso' and aura.swingUntil==0,'melee profile roundtrip')
assert(not s.SkipDowned,'downed preference saved in profile')
button('Reset defaults').callback()
assert(not s.Enabled and s.Range==10 and s.AutoAttack,'melee defaults')
assert(s.SkipDowned,'reset restores downed protection')
s.Enabled=true; aura:Step(15); local activation=aura.activation; local heartbeat=aura.connection
app:Unload()
assert(not activation.Connected and not heartbeat.Connected and not aura.target,'disconnect owned signals')
assert(getgenv().LegitMeleeRaycastHook.Owner==nil,'unload releases dispatcher owner')
unchanged('unloaded hook is transparent')
local second=assert(loadstring(SOURCES['main.lua']))()
second.Library:SetOpen(false); second.Config.Melee.Enabled=true; second.MeleeAura:Step(16)
assert(installed==1 and getgenv().LegitMeleeRaycastHook.Owner==second.MeleeAura,'reload reuses dispatcher')
second:Unload()
getgenv().LegitMeleeRaycastHook=nil; hookmetamethod=nil
local third=assert(loadstring(SOURCES['main.lua']))()
third.Library:SetOpen(false); third.Config.Melee.Enabled=true; third.MeleeAura:Step(17)
assert(third.MeleeAura.Status:find('Unavailable',1,true) and not third.MeleeAura.target,'missing APIs fail closed')
third:Unload()
print('PASS melee hook: scope, filters, cadence, manual swings, profiles, cleanup, reload and unsupported executors')
