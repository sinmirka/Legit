local app=assert(loadstring(SOURCES['main.lua']))()
local silent,s=app.SilentAim,app.Config.Silent
local players=MOCK.players
local vec=MOCK.vec
local function player(id,x,z)
    local p={UserId=id,Name='Silent'..id,DisplayName='Silent'..id,Parent=players,Neutral=false,Team={}}
    local char=Instance.new('Model'); char.Parent=workspace; p.Character=char
    local hum=Instance.new('Humanoid'); hum.Health=100; char.Children.Humanoid=hum
    for _,name in ipairs({'HumanoidRootPart','Head','Torso'}) do
        local part=Instance.new('Part'); part.Name=name; part.Parent=char; part.Position=vec(x,0,z)
        part.AssemblyLinearVelocity=vec(5,0,0); char.Children[name]=part
    end
    return p,char,hum
end
local localFixture,character=player(1,0,0)
players.LocalPlayer.Character=character
local target,targetChar,hum=player(2,6,30)
local other,otherChar=player(3,20,30)
players.list={players.LocalPlayer,target,other}
local gun=Instance.new('Tool'); gun.Name='Pistol'; gun.Parent=character; gun.Enabled=true
character.Children.Tool=gun
local values=Instance.new('Folder'); gun.Children.Values=values
values.Children.SERVER_Ammo=Instance.new('IntValue')
local caller=Instance.new('LocalScript'); caller.Name='GunClient'; caller.Parent=gun
local callingscript=caller
local method='Raycast'
local hooked,installed,lastArgs,failOriginal,executor=nil,0,nil,false,false
hookmetamethod=function(_,_,callback)
    installed+=1; hooked=callback
    return function(_, ...)
        assert(method=='Raycast','method context preserved')
        if failOriginal then error('original failure') end
        lastArgs=table.pack(...)
        return {Instance=targetChar.Children.Head},nil,'tail'
    end
end
getnamecallmethod=function() return method end
checkcaller=function() return executor end
getcallingscript=function() return callingscript end
newcclosure=function(fn) return fn end
local params={FilterType=Enum.RaycastFilterType.Exclude,FilterDescendantsInstances={character}}
local origin,direction=vec(0,0,0),vec(0,0,100)
local function cast()
    local result,middle,tail=hooked(workspace,origin,direction,params,nil,'extra')
    assert(result.Instance==targetChar.Children.Head and middle==nil and tail=='tail','game return tuple preserved')
    assert(lastArgs.n==5 and lastArgs[3]==params and lastArgs[5]=='extra','params and varargs preserved')
    return lastArgs[2]
end
app.Library:SetOpen(false)
silent:Step(0); assert(installed==0 and not silent.circle.Visible,'disabled has no hooks or FOV')
s.Enabled=true; silent:Step(1)
assert(installed==1 and silent.prepared.Target.Player==target,'independent screen selection')
local cameraFrame=workspace.CurrentCamera.CFrame
assert(cast()==direction,'does not redirect without firing')
gun.Activated:Fire()
local adjusted=cast()
assert(adjusted.X>0 and math.abs(adjusted.Magnitude-direction.Magnitude)<1e-8,'steer toward target and preserve ray length')
assert(workspace.CurrentCamera.CFrame==cameraFrame and not app.Config.Aim.Enabled,'camera never moves and Aim may stay disabled')
s.HitChance=0; assert(cast()==direction,'zero percent never redirects'); s.HitChance=100
executor=true; assert(cast()==direction,'executor rays bypass'); executor=false
origin=vec(100,0,0); assert(cast()==direction,'distant rays bypass'); origin=vec(0,0,0)
callingscript=Instance.new('ModuleScript'); callingscript.Name='RayHandler'
assert(cast()==direction,'name alone cannot authorize a shared caller')
local storage=MOCK.services.ReplicatedStorage
local modules=Instance.new('Folder'); storage.Children.NewModules=modules
local shared=Instance.new('Folder'); modules.Children.Shared=shared
local services=Instance.new('Folder'); shared.Children.Services=services
services.Children.RayHandler=callingscript
silent:Step(2); gun.Activated:Fire()
assert(cast()~=direction,'known game ray handler with local shooter filter is supported')
params.FilterDescendantsInstances={}; assert(cast()==direction,'other shooter rays bypass'); params.FilterDescendantsInstances={character}
params.FilterType=Enum.RaycastFilterType.Include; assert(cast()==direction,'include-filter shared rays bypass'); params.FilterType=Enum.RaycastFilterType.Exclude
callingscript=caller
hum.Health=0; assert(cast()==direction,'dead target invalidates cached ray immediately'); hum.Health=100
local focused=MOCK.services.UserInputService.GetFocusedTextBox
local candidate=app.Engine.Candidate
MOCK.services.UserInputService.GetFocusedTextBox=function() method='GetFocusedTextBox'; error('no Instance calls in hook') end
app.Engine.Candidate=function() method='FindFirstChild'; error('no target scan in hook') end
for _=1,1000 do assert(cast()~=direction and method=='Raycast','burst preserves namecall context') end
MOCK.services.UserInputService.GetFocusedTextBox=focused; app.Engine.Candidate=candidate
failOriginal=true; local ok,problem=pcall(cast)
assert(not ok and tostring(problem):find('original failure',1,true),'original errors propagate'); failOriginal=false
gun.Deactivated:Fire(); silent:Step(3); assert(cast()==direction,'stopping fire closes gate')
s.Radius=1; silent:Step(4); assert(not silent.prepared,'FOV filter'); s.Radius=160
workspace.Hit={Instance={IsDescendantOf=function() return false end}}
silent:Step(5); assert(not silent.prepared,'wall filter'); workspace.Hit=nil
app.Engine.playerModes[target.UserId]='Friend'; silent:Step(6)
assert(silent.prepared.Target.Player==other,'Friend priority excluded from silent')
app.Engine.playerModes[target.UserId]=nil; app.Engine.playerModes[other.UserId]='Enemy'; silent:Step(7)
assert(silent.prepared.Target.Player==other,'Enemy preferred'); app.Engine.playerModes[other.UserId]=nil
target.Team=players.LocalPlayer.Team; s.TeamCheck=true; silent:Step(8)
assert(silent.prepared.Target.Player==other,'team filter'); s.TeamCheck=false
hum.PlatformStand=true; silent:Step(9); assert(silent.prepared.Target.Player==other,'downed/ragdoll filter'); hum.PlatformStand=false
s.Part='UpperTorso'; s.Prediction=true; silent:Step(10)
assert(silent.prepared.Target.Part==targetChar.Children.Torso and silent.prepared.Target.Position.X>6,'R6 and prediction')
s.Part='Head'; s.Prediction=false
s.PauseMenu=true; app.Library:SetOpen(true); silent:Step(11); assert(not silent.prepared and not silent.circle.Visible,'menu pause')
app.Library:SetOpen(false); app.Engine.focused=false; silent:Step(12); assert(not silent.prepared,'focus pause'); app.Engine.focused=true
-- Both features share exactly one dispatcher and never steer a melee ray as a gun ray.
gun.Name='Fists'; app.Config.Melee.Enabled=true; app.Config.Melee.AutoAttack=false
targetChar.Children.Head.Position=vec(5,0,0); targetChar.Children.HumanoidRootPart.Position=vec(5,0,0)
app.MeleeAura:Step(13); silent:Step(13); gun.Activated:Fire()
assert(not silent.prepared and app.MeleeAura.target,'weapon scopes are disjoint')
direction=vec(0,0,1)
assert(cast()~=direction and installed==1,'melee still works with shared dispatcher')
direction=vec(0,0,100)
gun.Name='Pistol'; app.MeleeAura:Step(14); silent:Step(14); gun.Activated:Fire()
assert(silent.prepared and cast()~=direction and installed==1,'switching back to gun reuses dispatcher')
local function button(label)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,option in ipairs(section.options) do if option.class=='button' and option.text==label then return option end end
    end end
end
app.Library.options.Silent_HitChance:SetValue(65); button('Save profile').callback()
app.Library.options.Silent_HitChance:SetValue(0); button('Load profile').callback()
assert(s.HitChance==65,'silent profile roundtrip')
button('Reset defaults').callback(); assert(not s.Enabled and s.SkipDowned and s.HitChance==100,'safe defaults')
local circle=silent.circle; local connection=silent.connection
app:Unload()
assert(not silent.alive and not connection.Connected and not silent.tool and not circle.Visible,'silent cleanup')
assert(getgenv().LegitMeleeRaycastHook.SilentOwner==nil and getgenv().LegitMeleeRaycastHook.Owner==nil,'shared dispatcher releases both owners')
print('PASS Silent Aim: independent targeting, FOV/filters, fire/caller/origin scoping, ray length, 1000 safe calls, melee coexistence, profiles and cleanup')
