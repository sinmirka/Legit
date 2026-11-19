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

local events=Instance.new('Folder'); storage.Children.Events=events
local events2=Instance.new('Folder'); storage.Children.Events2=events2
local visualize=Instance.new('BindableEvent'); visualize.Event=visualize.Activated; events2.Children.Visualize=visualize
local hit=Instance.new('RemoteEvent'); events.Children.ZFKLF__H=hit
local reports=0; function hit:FireServer() reports+=1 end
local intercepted,rayArgs,rayCalls,rayInstalled=nil,nil,0,0
local wall=Instance.new('Part')
hookmetamethod=function(_,_,callback)
    rayInstalled+=1; intercepted=callback
    return function(receiver,...)
        rayCalls+=1; rayArgs=table.pack(...)
        local params=rayArgs[3]
        if params and params.FilterType==Enum.RaycastFilterType.Include then
            assert(params.FilterDescendantsInstances[1]==targetChar,'penetration query restricted to selected target')
            return {Instance=targetChar.Children.Head,Position=targetChar.Children.Head.Position},nil,'tail'
        end
        return {Instance=wall,Position=vec(0,0,1)},nil,'tail'
    end
end
getnamecallmethod=function() return 'Raycast' end
getcallingscript=nil -- Silent ray steering does not require caller introspection.
app.Library:SetOpen(false); s.Enabled=true
silent:Step(1)
assert(installed==4 and rayInstalled==1,'Visualize must not suppress Effects/FastCast/Raycast hooks')
assert(silent.Backend:find('Visualize',1,true) and silent.Backend:find('Gun directions',1,true) and silent.Backend:find('Raycast',1,true),'combined adapter status')
local list={direction}
hooks[effects]('Shoot',nil,'combined-shot',true,gun,origin,list,{})
assert(list[1].X>0 and (list[1]-direction).Magnitude>1,'real shared direction list changes while Visualize exists')
assert(effectsArgs[7]==list,'server and local Effects retain shared table')
local _,_,tail=hooks[api.Fire](caster,'combined-shot',origin,list[1],300,bullet,character,true,acceleration)
assert(tail=='tail' and lastArgs[4]==list[1],'original projectile receives the steered direction')
visualize.Event:Fire(nil,'combined-shot',nil,gun,nil,origin,list)
local pending=task.pending; task.pending={}; for _,thread in ipairs(pending) do assert(coroutine.resume(thread)) end
assert(reports==1,'reference hit report also remains active')
local params={FilterType=Enum.RaycastFilterType.Exclude,FilterDescendantsInstances={character}}
local hitResult,empty,returnTail=intercepted(workspace,origin,vec(0,0,1),params,nil,'extra')
assert(rayArgs[2].X>0 and rayArgs[2].Magnitude>30,'short projectile query redirected toward selected part')
assert(hitResult.Instance==wall and empty==nil and returnTail=='tail' and rayArgs[3]==params,'ordinary mode keeps actual wall collision and return tuple')
app.Library.options.Combat_WallBang:SetState(true); silent:Step(2)
local before=rayCalls
hitResult=intercepted(workspace,origin,vec(0,0,1),params,nil,'extra')
assert(rayCalls==before+1 and hitResult.Instance==targetChar.Children.Head,'wallbang changes actual query filter and returns original engine result')
assert(rayArgs[3]~=params and params.FilterType==Enum.RaycastFilterType.Exclude and params.FilterDescendantsInstances[1]==character,'game params never mutated')
assert(rayArgs.n==5 and rayArgs[4]==nil and rayArgs[5]=='extra','nil and extra arguments preserved')
intercepted(workspace,origin,vec(0,0,1)); assert(rayArgs.n==3 and rayArgs[3].FilterType==Enum.RaycastFilterType.Include,'omitted params inserted correctly')
intercepted(workspace,vec(200,0,0),direction,params); assert(rayArgs[2]==direction and rayArgs[3]==params,'distant nonweapon queries untouched')
s.HitChance=0; intercepted(workspace,origin,direction,params); assert(rayArgs[2]==direction and rayArgs[3]==params,'zero chance preserves direction and filter'); s.HitChance=100
app.Library.options.Combat_WallBang:SetState(false); silent:Step(3)
intercepted(workspace,origin,direction,params); assert(rayArgs[3]==params,'turning off restores normal collision parameters')
assert(installed==4 and rayInstalled==1,'no repeated hook chains')
s.Enabled=false; intercepted(workspace,origin,direction,params); assert(rayArgs[2]==direction,'disabled stops immediately')
app:Unload(); assert(not silent.raycastHook.SilentOwner,'unload releases shared hook ownership')
print('PASS combined silent: Visualize + actual gun directions + Raycast, real wallbang query filter, optional caller API and cleanup')
