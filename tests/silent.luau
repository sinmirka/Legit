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
local executor=false
local methods={'Fire','FireWithBlacklist','FireWithWhitelist'}
local api,hooks={},{}
local installed,originalCalls,lastArgs,failOriginal=0,0,nil,false
local caster={LengthChanged=Instance.new('BindableEvent').Activated,RayHit=Instance.new('BindableEvent').Activated}
for _,name in ipairs(methods) do
    api[name]=function(...)
        originalCalls+=1
        if failOriginal then error('original failure') end
        lastArgs=table.pack(...)
        return 'original',nil,'tail'
    end
end
local storage=MOCK.services.ReplicatedStorage
local modules=Instance.new('Folder'); storage.Children.NewModules=modules
local shared=Instance.new('Folder'); modules.Children.Shared=shared
local services=Instance.new('Folder'); shared.Children.Services=services
local module=Instance.new('ModuleScript'); services.Children.FastCastRedux=module
local client=Instance.new('Folder'); modules.Children.Client=client
local clientServices=Instance.new('Folder'); client.Children.Services=clientServices
local effectsModule=Instance.new('ModuleScript'); clientServices.Children.Effects=effectsModule
local effectsArgs
local effects=function(...) effectsArgs=table.pack(...); return 'effects',nil,'tail' end
require=function(value)
    if value==module then return api end
    if value==effectsModule then return effects end
    error('unknown module')
end
hookfunction=function(fn,callback)
    installed+=1; assert(not hooks[fn],'no duplicate hooks'); hooks[fn]=callback; return fn
end
checkcaller=function() return executor end
getcallingscript=function() return callingscript end
newcclosure=function(fn) return fn end
local origin,direction,velocity=vec(0,0,0),vec(0,0,100),vec(0,0,300)
local acceleration=vec(0,0,0)
local exclusions={character}
local bullet=Instance.new('Part')
local function fire(method)
    method=method or 'FireWithBlacklist'
    local args
    if method=='Fire' then
        args=table.pack(caster,42,origin,direction,velocity,bullet,character,true,acceleration,'x',nil,'y',nil)
    else
        args=table.pack(caster,42,origin,direction,velocity,exclusions,bullet,true,acceleration,'x',nil,'y',nil)
    end
    local list={direction}
    silent.ballistics={Velocity=type(velocity)=='number' and velocity or velocity.Magnitude,Acceleration=acceleration}
    local e1,e2,e3=(hooks[effects] or effects)('Shoot',nil,42,true,gun,origin,list,{})
    assert(e1=='effects' and e2==nil and e3=='tail','Effects result tuple retained')
    assert(effectsArgs[7]==list,'Gun and Effects retain identical list reference')
    args[4]=list[1]
    if typeof(velocity)=='Vector3' and velocity.Magnitude>0 then args[5]=list[1].Unit*velocity.Magnitude end
    local before=originalCalls
    local a,b,c=(hooks[api[method]] or api[method])(table.unpack(args,1,args.n))
    assert(a=='original' and b==nil and c=='tail','original return tuple preserved')
    assert(originalCalls==before+1 and lastArgs.n==13,'original runs exactly once, trailing nil retained')
    assert(lastArgs[4]==list[1] and (lastArgs[5]==args[5] or (args[5]~=args[5] and lastArgs[5]~=lastArgs[5])),
        'FastCast observes the server-bound direction without a second aim decision')
    for index=1,args.n do if index~=4 and index~=5 then assert(lastArgs[index]==args[index],'unrelated argument preserved: '..index) end end
    return lastArgs[4],lastArgs[5]
end
local function close(a,b) return (a-b).Magnitude<1e-7 end
app.Library:SetOpen(false)
silent:Step(0); assert(installed==0 and not silent.circle.Visible,'disabled installs nothing')
s.Enabled=true; silent:Step(1)
assert(installed==4 and silent.prepared.Target.Player==target,'independent target and shared Shoot and three observation entrypoints')
local cameraFrame=workspace.CurrentCamera.CFrame
for _,method in ipairs(methods) do
    local sent,speed=fire(method)
    assert(sent.X>0 and math.abs(sent.Magnitude-direction.Magnitude)<1e-8,'range and target direction')
    assert(math.abs(speed.Magnitude-velocity.Magnitude)<1e-8 and close(speed.Unit,sent.Unit),'vector velocity steered with direction')
end
assert(workspace.CurrentCamera.CFrame==cameraFrame and not app.Config.Aim.Enabled,'no camera movement')
local foreignList={direction}
hooks[effects]('Shoot',nil,43,false,gun,origin,foreignList,{})
assert(foreignList[1]==direction,'replicated Shoot effects never steer')
hooks[effects]('Reload',nil,43,true,gun,origin,foreignList,{})
assert(foreignList[1]==direction,'unrelated effects never mutate')
-- Regression: integrate the actual FastCast formula across multiple untouched segments.
local sent,speed=fire()
local actualVelocity=(sent.Unit+speed).Unit*speed.Magnitude
local t=(targetChar.Children.Head.Position-origin).Magnitude/actualVelocity.Magnitude
assert(close(origin+actualVelocity*t,targetChar.Children.Head.Position),'shared direction reaches target without per-segment rewrites')
velocity=300; sent,speed=fire(); assert(speed==300 and sent.X>0,'scalar speed retained')
velocity=vec(0,0,300); acceleration=vec(0,-196.2,0)
sent,speed=fire()
actualVelocity=(sent.Unit+speed).Unit*speed.Magnitude
local flight=30/actualVelocity.Z
assert(close(origin+actualVelocity*flight+acceleration*(flight^2/2),targetChar.Children.Head.Position),'gravity compensated at launch')
acceleration=vec(0,-1e9,0); assert(fire()==direction,'unreachable ballistic target passes unchanged')
acceleration=vec(0,0,0)
s.HitChance=0; assert(fire()==direction,'zero chance'); s.HitChance=100
assert(effectsArgs[7][1]==direction,'server-bound table keeps unchanged direction on rejection')
executor=true; assert(fire()==direction,'executor fire bypasses'); executor=false
origin=vec(100,0,0); assert(fire()==direction,'distant origin bypass'); origin=vec(0,0,0)
callingscript=module
assert(fire()==direction and fire('Fire')==direction,'foreign caller cannot modify gun direction list')
exclusions={otherChar}; assert(fire()==direction,'other shooter never redirected')
exclusions={character}; assert(fire('FireWithWhitelist')==direction,'local character in whitelist does not identify shooter')
callingscript=caller
hum.Health=0; assert(fire()==direction,'target death invalidates cached aim'); hum.Health=100
hum.PlatformStand=true; hum.Health=16; assert(fire()~=direction,'downed above 15 HP allowed'); hum.Health=15; assert(fire()==direction,'newly downed cached target skipped'); hum.PlatformStand=false; hum.Health=100
local focused=MOCK.services.UserInputService.GetFocusedTextBox
local candidate=app.Engine.Candidate
MOCK.services.UserInputService.GetFocusedTextBox=function() error('input query in hot path') end
app.Engine.Candidate=function() error('target scan in hot path') end
s.ShowTracers=false
for _=1,1000 do assert(fire()~=direction,'burst uses prepared target') end
MOCK.services.UserInputService.GetFocusedTextBox=focused; app.Engine.Candidate=candidate
s.ShowTracers=true
failOriginal=true; local ok,problem=pcall(fire)
assert(not ok and tostring(problem):find('original failure',1,true),'game errors propagate'); failOriginal=false
local redirect=silent.AimLaunch
silent.AimLaunch=function() error('adapter error') end
assert(fire()==direction,'adapter failure preserves original shot'); silent.AimLaunch=redirect
velocity=vec(0,0,0); assert(fire()==direction,'zero speed passes unchanged')
velocity=0/0; assert(fire()==direction,'NaN speed passes unchanged')
velocity=vec(0,0,300)
s.Radius=1; silent:Step(4); assert(not silent.prepared,'FOV filter'); s.Radius=160
workspace.Hit={Instance={IsDescendantOf=function() return false end}}
silent:Step(5); assert(not silent.prepared,'wall filter'); workspace.Hit=nil
app.Engine.playerModes[target.UserId]='Friend'; silent:Step(6)
assert(silent.prepared.Target.Player==other,'Friend priority excluded from silent')
app.Engine.playerModes[target.UserId]=nil; app.Engine.playerModes[other.UserId]='Enemy'; silent:Step(7)
assert(silent.prepared.Target.Player==other,'Enemy preferred'); app.Engine.playerModes[other.UserId]=nil
target.Team=players.LocalPlayer.Team; s.TeamCheck=true; silent:Step(8)
assert(silent.prepared.Target.Player==other,'team filter'); s.TeamCheck=false
hum.PlatformStand=true; hum.Health=15; silent:Step(9); assert(silent.prepared.Target.Player==other,'downed/ragdoll filter'); hum.PlatformStand=false; hum.Health=100
s.Part='UpperTorso'; s.Prediction=true; silent:Step(10)
assert(silent.prepared.Target.Part==targetChar.Children.Torso and silent.prepared.Target.Position.X>6,'R6 and prediction')
s.Part='Head'; s.Prediction=false
s.PauseMenu=true; app.Library:SetOpen(true); silent:Step(11); assert(not silent.prepared and not silent.circle.Visible,'menu pause')
app.Library:SetOpen(false); app.Engine.focused=false; silent:Step(12); assert(not silent.prepared,'focus pause'); app.Engine.focused=true
-- Fists remain excluded, and Silent needs no workspace __namecall hook.
gun.Name='Fists'; silent:Step(13); assert(not silent.prepared,'melee excluded')
gun.Name='Pistol'; silent:Step(14); assert(silent.prepared and installed==4,'switch reuses hooks')
assert(getgenv().LegitMeleeRaycastHook==nil,'Silent does not touch workspace Raycast')
-- Only actual FastCast signals create trace endpoints, not the selected target.
silent:Reset(); silent:Step(20); silent.nextTrace=0; fire()
assert(#silent.traceQueue==0 and #silent.tracePool==0,'launch alone is not a fabricated hit/path')
local endpoint=vec(8,0,32)
caster.LengthChanged:Fire(origin,origin,endpoint.Unit,endpoint.Magnitude,velocity,bullet)
assert(#silent.traceQueue==1 and close(silent.traceQueue[1].End,endpoint),'real simulated endpoint recorded')
local shot=silent.traceQueue[1]
assert(shot.Redirected and not shot.Hit,'segment is not hit confirmation')
caster.RayHit:Fire(42,origin,direction.Unit,targetChar.Children.Head,endpoint,nil,nil,nil,velocity,bullet)
assert(shot.Hit and shot.End==endpoint,'actual client hit signal recorded')
silent:Render(os.clock())
assert(#silent.tracePool==1 and silent.tracePool[1].Sent.Visible,'actual flight rendered')
assert(silent.tracePool[1].Dot.Position.X==648 and silent.targetDot.Position.X==646,'target guide distinct from client hit')
s.Radius=1; silent:Step(21); silent.nextTrace=0; assert(fire()==direction,'no target leaves trajectory intact')
caster.LengthChanged:Fire(origin,origin,direction.Unit,20,velocity,bullet)
assert(silent.traceQueue[1].Reason=='no target','unmodified launch reason recorded')
silent:Render(os.clock()); assert(silent.tracePool[2].Label.Text:find('PASS: no target',1,true),'passthrough label')
s.Radius=160; silent:Step(22)
for index=1,100 do
    bullet=Instance.new('Part'); silent.nextTrace=0; fire()
    caster.LengthChanged:Fire(origin,origin,direction.Unit,index,velocity,bullet)
end
assert(#silent.traceQueue==16,'bounded queue')
local retained=0; for _ in pairs(silent.projectiles) do retained+=1 end
assert(retained==16,'bounded active projectile records')
silent:Render(os.clock()); assert(#silent.shots==16 and #silent.tracePool==16,'bounded visual pool')
silent:Render(os.clock()+s.TraceDuration+1); assert(#silent.shots==0 and not silent.tracePool[1].Sent.Visible,'expiry')
silent.nextTrace=0; fire(); caster.LengthChanged:Fire(origin,origin,direction.Unit,20,velocity,bullet); silent:Render(os.clock())
s.ShowTracers=false; silent:Render(os.clock()); assert(#silent.shots==0 and not silent.tracePool[1].Sent.Visible,'traces disable')
s.ShowTracers=true; s.ShowOriginalRay=false; silent.nextTrace=0; fire()
caster.LengthChanged:Fire(origin,origin,direction.Unit,20,velocity,bullet); silent:Render(os.clock())
assert(not silent.tracePool[1].Original.Visible,'original overlay independently hidden')
local trackedConnection=silent.casters[1].Connections[1]
silent:Reset()
assert(not trackedConnection.Connected and next(silent.projectiles)==nil and #silent.casters==0,'reset disconnects observers')
local function button(label)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,option in ipairs(section.options) do if option.class=='button' and option.text==label then return option end end
    end end
end
app.Library.options.Silent_HitChance:SetValue(65); button('Save profile').callback()
app.Library.options.Silent_HitChance:SetValue(0); button('Load profile').callback()
assert(s.HitChance==65,'silent profile roundtrip')
button('Reset defaults').callback(); assert(not s.Enabled and s.SkipDowned and s.HitChance==100,'safe defaults')
local circle,connection=silent.circle,silent.connection
local state=silent.projectileHook
app:Unload()
assert(not silent.alive and not connection.Connected and not circle.Visible and state.Owner==nil and silent.effectsHook.Owner==nil,'unload releases both adapters')
assert(fire()==direction,'installed function wrappers pass through after unload')
-- Reload shares existing native hooks instead of adding new wrapper chains.
local nextApp=assert(loadstring(SOURCES['main.lua']))()
local nextSilent=nextApp.SilentAim
nextApp.Library:SetOpen(false); nextApp.Config.Silent.Enabled=true; nextSilent:Step(30)
assert(installed==4 and state.Owner==nextSilent,'reload reuses hooks')
hookfunction=nil; nextSilent:Step(31)
assert(not nextSilent.prepared and nextSilent.Status:find('hookfunction',1,true),'missing capability is explicit')
nextApp:Unload()
print('PASS Silent Aim: shared client/server direction list + vector/scalar speed, multi-frame trajectory, gravity, shooter/target filters, bounded real signal traces, 1000 calls, failure passthrough and reload cleanup')
