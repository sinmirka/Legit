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
app.Engine.friends[near]=false; app.Engine.friends[far]=false
local tool=Instance.new('Tool'); tool.Name='Fists'; tool.Parent=character; tool.Enabled=true
character.Children.Tool=tool
local attacks=0
function tool:Activate() attacks+=1; self.Activated:Fire() end

local storage=MOCK.services.ReplicatedStorage
local events=Instance.new('Folder'); storage.Children.Events=events
local start=Instance.new('RemoteEvent'); events.Children['XMHH.2']=start
local hit=Instance.new('RemoteEvent'); events.Children['XMHH2.2']=hit
local swing=Instance.new('RemoteFunction')
function storage:GetDescendants() return {events,start,hit,swing} end
local starts,hits,swings={},{},{}
function start:FireServer(...) table.insert(starts,table.pack(...)) end
function hit:FireServer(...) table.insert(hits,table.pack(...)) end
function swing:InvokeServer(...) table.insert(swings,table.pack(...)) end
hookmetamethod=nil; getnamecallmethod=nil; checkcaller=nil; getcallingscript=nil
local function flush()
    local pending=task.pending; task.pending={}
    for _,thread in ipairs(pending) do assert(coroutine.resume(thread)) end
end
app.Library:SetOpen(false); s.Enabled=true
aura:Step(0)
assert(aura.Backend=='Criminality remotes' and #swings==1 and #hits==0,'no-hook handshake before delayed hit')
flush()
assert(#starts==1 and #hits==1,'paired reports')
local a,b=starts[1],hits[1]
assert(a.n==7 and a[3]==tool and a[4]=='43TRFWX' and a[6][1]==nearChar.Children.Head and a[7]==false,'start protocol')
assert(b.n==7 and b[1]==utf8.char(129480) and b[2]==tool and b[3]==a[2] and b[4]==1
    and b[5]==nearChar.Children.Head and b[7]==nil,'hit protocol shares identifier and retains nil')
assert(#a[2]==31 and a[2]:match('^%l+0$'),'reference identifier format')
aura:Step(0.1); flush(); assert(#hits==1,'configured interval')
tool.Name='Shovel'; aura:Step(1); flush(); assert(#hits==2,'shovel swing')
aura:Step(2); flush(); assert(#hits==2,'weapon cooldown respected')
aura:Step(4); s.Enabled=false; flush(); assert(#hits==2,'disable cancels pending hit'); s.Enabled=true
aura:Step(7); nearChar.Children.Head.Position=vec(100,0,0); flush(); assert(#hits==2,'range rechecked after delay'); nearChar.Children.Head.Position=vec(5,0,0)
aura:Step(10); nearHum.Health=0; flush(); assert(#hits==2,'death rechecked'); nearHum.Health=100
aura:Step(13); app.Engine.playerModes[near.UserId]='Friend'; flush(); assert(#hits==2,'friend rechecked'); app.Engine.playerModes[near.UserId]=nil
aura:Step(16); tool.Parent=nil; flush(); assert(#hits==2,'unequip cancels'); tool.Parent=character
s.AutoAttack=false; aura:Step(20); flush(); assert(#hits==2,'manual mode waits for swing')
aura.nextAttack=0; tool.Activated:Fire(); flush(); assert(#hits==3,'manual activation reports hit')
aura.nextAttack=0; tool.Activated:Fire(); aura:Reset(); flush(); assert(#hits==3,'reset cancels pending work')
s.AutoAttack=true; aura:Step(25); app:Unload(); flush(); assert(#hits==3,'unload cancels pending work')
assert(not aura.activation and not aura.pendingAttack,'resources cleaned')
print('PASS Criminality melee remotes: handshake, paired IDs, cooldowns, manual mode, delayed filters and cleanup without hooks')
