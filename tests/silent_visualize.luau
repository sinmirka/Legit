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

local storage=MOCK.services.ReplicatedStorage
local events=Instance.new('Folder'); storage.Children.Events=events
local events2=Instance.new('Folder'); storage.Children.Events2=events2
local visualize=Instance.new('BindableEvent'); visualize.Event=visualize.Activated; events2.Children.Visualize=visualize
local hit=Instance.new('RemoteEvent'); events.Children.ZFKLF__H=hit
local reports={}
function hit:FireServer(...) table.insert(reports,table.pack(...)) end
hookfunction=nil; checkcaller=nil; hookmetamethod=nil; getnamecallmethod=nil
app.Library:SetOpen(false); s.Enabled=true
silent:Step(1)
assert(silent.prepared and silent.Backend=='Criminality Visualize','event backend needs no hook APIs')
local function flush()
    local pending=task.pending; task.pending={}
    for _,thread in ipairs(pending) do assert(coroutine.resume(thread)) end
end
local directions={vec(0,0,100),vec(1,0,100)}
local function shot(id,weapon,origin)
    visualize.Event:Fire(nil,id,nil,weapon or gun,nil,origin or vec(0,0,0),directions)
end
shot('first'); assert(#reports==0,'reports deferred until game processes launch'); flush()
assert(#reports==2,'one report per pellet')
for index,args in ipairs(reports) do
    assert(args.n==7 and args[1]==utf8.char(129480) and args[2]==gun and args[3]=='first'
        and args[4]==index and args[5]==targetChar.Children.Head,'reference protocol')
    assert((args[7]-(targetChar.Children.Head.Position).Unit).Magnitude<1e-7,'direction toward target')
end
shot('first'); flush(); assert(#reports==2,'duplicate event ignored')
shot('foreign',Instance.new('Tool')); flush(); assert(#reports==2,'foreign shooter ignored')
s.HitChance=0; shot('miss'); flush(); assert(#reports==2,'zero hit chance'); s.HitChance=100
shot('disabled'); s.Enabled=false; flush(); assert(#reports==2,'disable cancels queued reports'); s.Enabled=true
shot('friend'); app.Engine.playerModes[target.UserId]='Friend'; flush(); assert(#reports==2,'late friend change'); app.Engine.playerModes[target.UserId]=nil
shot('wall'); workspace.Hit={Instance=Instance.new('Part')}; workspace.Hit.Instance.IsDescendantOf=function() return false end
flush(); assert(#reports==2,'late wall change'); workspace.Hit=nil
shot('dead'); hum.Health=0; flush(); assert(#reports==2,'late death'); hum.Health=100
shot('swapped'); gun.Parent=nil; flush(); assert(#reports==2,'unequip cancels'); gun.Parent=character
shot('reset'); silent:Reset(); flush(); assert(#reports==2,'reset cancels pending work')
silent:Step(2); shot('respawn'); players.LocalPlayer.Character=nil; flush(); assert(#reports==2,'respawn cancels'); players.LocalPlayer.Character=character
silent:Step(3); shot('unload'); app:Unload(); flush(); assert(#reports==2,'unload cancels pending work')
shot('after'); flush(); assert(#reports==2,'listener disconnected')
print('PASS Criminality Visualize: no hooks, pellet protocol, deduplication, chance, filters and delayed cancellation')
