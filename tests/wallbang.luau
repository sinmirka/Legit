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

local config,engine=app.Config,app.Engine
local toggle=assert(app.Library.options.Combat_WallBang,'Wall Bang control')
assert(config.Combat.WallBang==false and s.WallCheck,'disabled by default')
local wall=Instance.new('Part'); wall.IsDescendantOf=function() return false end
workspace.Hit={Instance=wall}
silent:Step(2); assert(not silent.prepared,'wall blocks normal silent aim')
local camera,root=workspace.CurrentCamera,character.Children.HumanoidRootPart
assert(not engine:Candidate(target,camera,root,config.Aim),'wall blocks camera aim')
toggle:SetState(true)
assert(config.Combat.WallBang and s.WallCheck and config.Aim.WallCheck,'override keeps individual wall settings')
silent:Step(3)
assert(silent.prepared and engine:Candidate(target,camera,root,config.Aim),'reference override allows targets behind wall')
shot('through-wall'); flush(); assert(#reports==2,'event hit reports behind wall')
-- The override affects visibility only: all other target filters still apply.
engine.playerModes[target.UserId]='Friend'; shot('friend'); flush(); assert(#reports==2,'friend filter remains'); engine.playerModes[target.UserId]=nil
hum.Health=0; shot('dead'); flush(); assert(#reports==2,'health filter remains'); hum.Health=100
targetChar.Children.ForceField=Instance.new('ForceField'); shot('shield'); flush(); assert(#reports==2,'forcefield remains'); targetChar.Children.ForceField=nil
s.MaxDistance=1; shot('range'); flush(); assert(#reports==2,'distance filter remains'); s.MaxDistance=1000
s.HitChance=0; shot('chance'); flush(); assert(#reports==2,'hit chance remains'); s.HitChance=100
shot('cancelled'); toggle:SetState(false); flush(); assert(#reports==2,'turning off cancels delayed hit')
silent:Step(4); assert(not silent.prepared,'wall checking resumes')
s.WallCheck=false; silent:Step(5); assert(silent.prepared,'independent disabled wall check still works')
s.WallCheck=true
-- Melee uses the same override and rechecks it after the handshake delay.
local melee,m=app.MeleeAura,config.Melee
engine.friends[target]=false
local start=Instance.new('RemoteEvent'); events.Children['XMHH.2']=start
local meleeHit=Instance.new('RemoteEvent'); events.Children['XMHH2.2']=meleeHit
local hits,starts=0,0
function start:FireServer() starts+=1 end
function meleeHit:FireServer() hits+=1 end
gun.Name='Fists'; targetChar.Children.Head.Position=vec(5,0,0)
function gun:Activate() self.Activated:Fire() end
targetChar.Children.HumanoidRootPart.Position=vec(5,0,0)
players.list={players.LocalPlayer,target}
m.Enabled=true; m.AutoAttack=true
melee:Step(0); assert(not melee.target,'normal melee checks wall')
toggle:SetState(true); melee:Step(1); assert(melee.target,'melee allows target behind wall: '..melee.Status); flush()
assert(starts==1 and hits==1,'paired melee reports behind wall')
melee:Step(2); toggle:SetState(false); flush(); assert(hits==1,'turning off cancels delayed melee hit')
melee:Step(3); assert(not melee.target,'melee resumes wall check')
-- Saving/loading and reset use the common profile controls.
local function button(label)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,item in ipairs(section.options) do if item.class=='button' and item.text==label then return item end end
    end end
    error('Missing button '..label)
end
toggle:SetState(true); button('Save profile').callback()
toggle:SetState(false); button('Load profile').callback(); assert(config.Combat.WallBang,'profile restores wallbang')
button('Reset defaults').callback(); assert(not config.Combat.WallBang,'defaults disable wallbang')
app:Unload()
print('PASS Wall Bang: UI, default off, actual gun/melee reports through walls, delayed cancellation, other filters and profiles')
