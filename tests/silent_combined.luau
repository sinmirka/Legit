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
local rayInstalled,intercepted,rayArgs=0,nil,nil
hookmetamethod=function(_,_,callback)
    rayInstalled+=1; intercepted=callback
    return function(_,...) rayArgs=table.pack(...); return 'actual-ray-result',nil,'tail' end
end
getnamecallmethod=function() return 'Raycast' end
-- Real FastCast methods can delegate; nested entry points must not adapt twice.
api.FireWithBlacklist=function(...) return hooks[api.Fire](...) end
app.Library:SetOpen(false); s.Enabled=true; silent:Step(1)
assert(installed==4 and rayInstalled==0,'default mode only installs launch hooks, never a per-segment global ray hook')
assert(silent.Backend:find('Visualize',1,true) and silent.Backend:find('Gun directions',1,true),'combined event and launch adapters')
local list={direction}; hooks[effects]('Shoot',nil,'shot',true,gun,origin,list,{})
assert(list[1].X>0 and effectsArgs[7]==list,'real shared local/server direction list changes')
local projectileCalls=0; local projectile=silent.Projectile
silent.Projectile=function(self,...) projectileCalls+=1; return projectile(self,...) end
local a,b,c=hooks[api.FireWithBlacklist](caster,'shot',origin,list[1],300,exclusions,bullet,true,acceleration)
assert(a=='original' and b==nil and c=='tail' and projectileCalls==1,'nested FastCast calls adapt once and preserve returns')
assert(lastArgs[4]==list[1] and lastArgs[4].Magnitude==list[1].Magnitude,'launch direction handed to original unchanged after preparation')
visualize.Event:Fire(nil,'shot',nil,gun,nil,origin,list)
local pending=task.pending; task.pending={}; for _,thread in ipairs(pending) do assert(coroutine.resume(thread)) end
assert(reports==1,'hit report remains active')
app.Library.options.Combat_WallBang:SetState(true); silent:Step(2)
assert(rayInstalled==0 and not silent:Redirect(nil,origin,vec(0,0,1)),'Wall Bang must not stretch FastCast segments or install global query filter')
-- Adapter errors must release the coroutine guard for the next real shot.
silent.Projectile=function() error('adapter failed') end
assert(hooks[api.FireWithBlacklist](caster,'shot',origin,list[1],300,exclusions,bullet,true,acceleration)=='original','adapter failure passes through')
silent.Projectile=function(self,...) projectileCalls+=1; return projectile(self,...) end
local before=projectileCalls
hooks[api.FireWithBlacklist](caster,'shot',origin,list[1],300,exclusions,bullet,true,acceleration)
assert(projectileCalls==before+1,'guard clears after adapter failure')
-- Explicit Universal mode retains the original ray length and collision params.
app.Library.options.Silent_Universal:SetState(true); silent:Step(3)
assert(rayInstalled==1,'only explicit Universal mode attaches ray steering')
local params={FilterType=Enum.RaycastFilterType.Exclude,FilterDescendantsInstances={character}}
intercepted(workspace,origin,vec(0,0,1),params)
assert(rayArgs[2].Magnitude==1 and rayArgs[3]==params,'short segments never extended or given a different collision filter')
intercepted(workspace,origin,vec(0,0,100),params)
assert(math.abs(rayArgs[2].Magnitude-100)<1e-8 and rayArgs[3]==params,'long rays retain length and params even with Wall Bang')
app:Unload(); assert(not silent.raycastHook.SilentOwner,'cleanup')
print('PASS stable launch hooks: Visualize + directions, no default ray interception, nested FastCast guard, original ray invariants')
