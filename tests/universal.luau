local players=MOCK.players
local function makePlayer(id,name)
    local player={UserId=id,Name=name,DisplayName='Display '..name,Parent=players,Neutral=false,Team={}}
    local character=Instance.new('Model'); character.Parent=workspace
    local hum=Instance.new('Humanoid'); hum.Health=100; hum.Parent=character
    hum.WalkSpeed=16; hum.UseJumpPower=true; hum.JumpPower=50; hum.JumpHeight=7.2
    function hum:ChangeState(state) self.LastState=state end
    character.Children.Humanoid=hum
    local root=Instance.new('Part'); root.Parent=character; root.Position=MOCK.vec(id*2,0,30)
    root.CanCollide=true; root.Name='HumanoidRootPart'; character.Children.HumanoidRootPart=root
    local head=Instance.new('Part'); head.Parent=character; head.Position=root.Position; head.Name='Head'
    head.CanCollide=false; character.Children.Head=head
    function character:GetDescendants() return {hum,root,head} end
    player.Character=character
    return player,hum,root,head
end
local localFixture,localHum,localRoot,localHead=makePlayer(1,'Local')
players.LocalPlayer.Character=localFixture.Character
local other,otherHum=makePlayer(2,'Alpha')
local enemy=makePlayer(3,'Beta')
players.list={players.LocalPlayer,other,enemy}
local prompt=Instance.new('ProximityPrompt'); prompt.Parent=workspace; prompt.HoldDuration=2
local unrelated=Instance.new('Part'); unrelated.Parent=workspace
local promptScans=0
workspace.GetDescendants=function() promptScans+=1; return {prompt,unrelated} end
workspace.DescendantAdded=Instance.new('BindableEvent').Activated
MOCK.services.ProximityPromptService={PromptShown=Instance.new('BindableEvent').Activated}
local app=assert(loadstring(SOURCES['main.lua']))()
local tools=app.Tools
local c,w=app.Config.Character,app.Config.World
local lighting=MOCK.services.Lighting
local function option(name) return assert(app.Library.options[name],name) end
local function button(text)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,item in ipairs(section.options) do if item.class=='button' and item.text==text then return item end end
    end end
    error('missing button: '..text)
end
assert(not app.Config.Interaction.Instant and prompt.HoldDuration==2 and promptScans==0,'instant interactions disabled by default')
option('Interaction_Instant'):SetState(true)
assert(prompt.HoldDuration==0 and promptScans==1,'existing prompts become instant immediately')
for _=1,100 do tools:Step() end
assert(promptScans==1,'no per-frame workspace traversal')
prompt.HoldDuration=3; tools:Step(); assert(prompt.HoldDuration==0,'game hold-time changes reconciled')
local spawned=Instance.new('ProximityPrompt'); spawned.Parent=workspace; spawned.HoldDuration=4
workspace.DescendantAdded:Fire(spawned); tools:Step(); assert(spawned.HoldDuration==0,'new prompts included')
local shown=Instance.new('ProximityPrompt'); shown.Parent=workspace; shown.HoldDuration=5
MOCK.services.ProximityPromptService.PromptShown:Fire(shown)
assert(shown.HoldDuration==0,'shown prompts updated immediately')
option('Interaction_Instant'):SetState(false)
assert(prompt.HoldDuration==3 and spawned.HoldDuration==4 and shown.HoldDuration==5,'disable restores latest owned hold duration')
option('Interaction_Instant'):SetState(true)
button('Save profile').callback(); option('Interaction_Instant'):SetState(false); button('Load profile').callback()
assert(app.Config.Interaction.Instant and prompt.HoldDuration==0,'interaction profile roundtrip')
option('Interaction_Instant'):SetState(false)
for _,removed in ipairs({'InfiniteJump','JumpOverride','JumpPower','JumpHeight','WalkSpeed','SpeedMethod'}) do
    assert(not app.Library.options['Character_'..removed],'removed movement control: '..removed)
end
-- Old runtime/profile fields cannot revive removed property writes or jump handlers.
c.JumpOverride=true; c.InfiniteJump=true; c.WalkSpeed=true; c.SpeedMethod='WalkSpeed'; c.JumpPower=80
localHum.LastState=nil; tools:Step(); MOCK.services.UserInputService.JumpRequest:Fire()
assert(localHum.WalkSpeed==16 and localHum.JumpPower==50 and localRoot.CanCollide and not localHum.LastState,'legacy fields cannot run removed methods')
c.JumpOverride=nil; c.InfiniteJump=nil; c.WalkSpeed=nil; c.SpeedMethod=nil; c.JumpPower=nil
option('Character_Noclip'):SetState(true)
assert(not localRoot.CanCollide and not localHead.CanCollide,'noclip applies all body parts')
localRoot.CanCollide=true; MOCK.services.RunService.Stepped:Fire()
assert(not localRoot.CanCollide,'noclip reapplied before physics')
option('Character_Noclip'):SetState(false)
assert(localRoot.CanCollide and not localHead.CanCollide,'original collisions restored')
option('Character_Noclip'):SetState(true)
local replacement=makePlayer(1,'NoclipRespawn')
players.LocalPlayer.Character=replacement.Character; tools:Step()
assert(localRoot.CanCollide and not replacement.Character.Children.HumanoidRootPart.CanCollide,'respawn restores old rig and applies new')
option('Character_Noclip'):SetState(false)
players.LocalPlayer.Character=localFixture.Character
c.Speed=35
local newFixture,newHum=makePlayer(1,'Respawn')
players.LocalPlayer.Character=newFixture.Character; tools:Step()
app.Library:SetOpen(false)
local beforeAmbient=lighting.Ambient
option('World_Time'):SetValue(3); option('World_TimeEnabled'):SetState(true)
option('World_RemoveShadows'):SetState(true)
option('World_AmbientEnabled'):SetState(true)
assert(lighting.ClockTime==3 and not lighting.GlobalShadows and lighting.Ambient==w.Ambient,'world overrides')
option('World_TimeEnabled'):SetState(false)
option('World_RemoveShadows'):SetState(false)
option('World_AmbientEnabled'):SetState(false)
assert(lighting.ClockTime==14 and lighting.GlobalShadows and lighting.Ambient==beforeAmbient,'world restore')
option('World_ExposureEnabled'):SetState(true)
lighting.ExposureCompensation=1.2
option('World_ExposureEnabled'):SetState(false)
assert(lighting.ExposureCompensation==1.2,'do not overwrite newer game writes on disable')
option('World_BloomEnabled'):SetState(true); local bloom=tools.effects.Bloom
option('World_BloomIntensity'):SetValue(2)
assert(bloom.Intensity==2,'owned bloom controls')
option('World_BloomEnabled'):SetState(false); assert(bloom.Destroyed,'destroy only owned bloom')
local originalAtmosphere=Instance.new('Atmosphere'); originalAtmosphere.Parent=lighting
originalAtmosphere.Density=0.1; originalAtmosphere.Haze=2; originalAtmosphere.Color=Color3.new(0,0,1)
lighting.Children.Atmosphere=originalAtmosphere
option('World_AtmosphereEnabled'):SetState(true); assert(originalAtmosphere.Density==w.Density,'existing atmosphere')
option('World_AtmosphereEnabled'):SetState(false)
assert(originalAtmosphere.Density==0.1 and not originalAtmosphere.Destroyed,'restore existing atmosphere')
lighting.Children.Atmosphere=nil
option('World_AtmosphereEnabled'):SetState(true); local ownedAtmosphere=tools.effects.Atmosphere
option('World_AtmosphereEnabled'):SetState(false); assert(ownedAtmosphere.Destroyed,'remove owned atmosphere')
local labels,map=tools:PlayerList('aLpHa')
assert(#labels==1 and map[labels[1]]==other,'literal case-insensitive player search')
assert(#tools:PlayerList('[abc')==0,'search does not interpret patterns')
option('Players_Search'):SetInput('Alpha')
local playerLabel='Display Alpha (@Alpha)'
option('Players_Selected'):Select(playerLabel)
assert(tools.Selected==other,'UI player selection')
option('Players_Priority'):Select('Friend'); button('Apply priority').callback()
assert(not app.Engine:Allowed(other,app.Config.Aim) and not app.Engine:Allowed(other,app.Config.Melee),'Friend excluded from combat')
assert(app.Engine:Allowed(other,app.Config.ESP),'Friend remains visible in ESP')
option('Players_Priority'):Select('Enemy'); button('Apply priority').callback()
assert(app.Engine:TargetRank(other)<app.Engine:TargetRank(enemy),'Enemy rank')
local a=app.Config.Aim; a.Sticky=false; a.WallCheck=false
app.Engine.playerModes[other.UserId]=nil; app.Engine.playerModes[enemy.UserId]='Enemy'
local candidate=app.Engine:Choose(workspace.CurrentCamera,newFixture.Character.Children.HumanoidRootPart,100)
assert(candidate and candidate.Player==enemy,'Aim prefers an eligible Enemy over nearer Neutral')
app.Config.Melee.Enabled=true; app.Config.Melee.PauseMenu=false; app.Config.Melee.AutoAttack=false
-- Test the shared Melee selection path without depending on executor hooks.
app.MeleeAura.InstallHook=function() return true end
app.MeleeAura.CapabilityProblem=function() return nil end
local tool=Instance.new('Tool'); tool.Name='Fists'; tool.Enabled=true; tool.Parent=newFixture.Character
newFixture.Character.Children.Tool=tool
app.MeleeAura:Step(101)
assert(app.MeleeAura.target and app.MeleeAura.target.Player==enemy,'Melee prefers eligible Enemy')
local camera=workspace.CurrentCamera; camera.CameraSubject=newHum
button('Spectate selected').callback(); assert(camera.CameraSubject==otherHum,'spectate selection')
button('Stop spectating').callback(); assert(camera.CameraSubject==newHum,'restore camera subject')
button('Spectate selected').callback()
players.PlayerRemoving:Fire(other)
assert(not tools.Selected and not tools.Spectating and camera.CameraSubject==newHum,'leaving target restores camera')
option('World_TimeEnabled'):SetState(true); option('Character_VelocitySpeed'):SetState(true)
button('Save profile').callback()
option('World_Time'):SetValue(8); option('Character_Speed'):SetValue(70)
button('Load profile').callback()
assert(lighting.ClockTime==3 and c.Speed==35 and c.VelocitySpeed and newHum.WalkSpeed==16,'velocity profile roundtrip without humanoid writes')
-- External launchers are lazy and tested with inert responses, never downloaded/executed here.
local clipboard
setclipboard=function(text) clipboard=text end
game.PlaceId=123; game.JobId='test-server'
-- Server info copy is no longer exposed; rejoin remains available.
local teleported
MOCK.services.TeleportService={TeleportToPlaceInstance=function(_,place,job,player) teleported={place,job,player} end}
button('Rejoin server').callback()
assert(teleported[1]==123 and teleported[2]=='test-server' and teleported[3]==players.LocalPlayer,'rejoin current server')
local requests=0
local http=game.HttpGet
game.HttpGet=function(_,url)
    requests+=1
    assert(url==tools.Scripts.Dex.URL or url==tools.Scripts.RemoteSpy.URL,'fixed source URL')
    return 'getgenv().TEST_EXTERNAL_LAUNCH=(getgenv().TEST_EXTERNAL_LAUNCH or 0)+1'
end
tools:RunScript('Dex'); tools:RunScript('Dex')
assert(requests==1 and getgenv().TEST_EXTERNAL_LAUNCH==1,'lazy launch and duplicate guard')
game.HttpGet=function() requests+=1; return '<html>error</html>' end
tools:RunScript('RemoteSpy')
assert(not tools.launched.RemoteSpy,'invalid response allows retry')
game.HttpGet=function() return 'error("startup failure")' end
tools:RunScript('RemoteSpy'); assert(not tools.launched.RemoteSpy,'runtime failure allows retry')
game.HttpGet=function() return 'this is not Lua' end
tools:RunScript('RemoteSpy'); assert(not tools.launched.RemoteSpy,'compile failure allows retry')
game.HttpGet=function() error('network failure') end
tools:RunScript('RemoteSpy'); assert(not tools.launched.RemoteSpy,'network failure allows retry')
game.HttpGet=http
-- Criminality-style horizontal root velocity, with original Y physics intact.
local movementRoot=newFixture.Character.Children.HumanoidRootPart
newHum.MoveDirection=MOCK.vec(0.6,0,0.8); movementRoot.AssemblyLinearVelocity=MOCK.vec(1,12,2)
option('Character_Speed'):SetValue(40)
option('Character_VelocitySpeed'):SetState(true)
assert(movementRoot.AssemblyLinearVelocity.X==24 and movementRoot.AssemblyLinearVelocity.Z==32 and movementRoot.AssemblyLinearVelocity.Y==12,'velocity method preserves Y and applies horizontal speed')
assert(newHum.WalkSpeed==16,'velocity leaves humanoid speed unchanged')
newHum.MoveDirection=MOCK.vec(0,0,0); local idleVelocity=movementRoot.AssemblyLinearVelocity; tools:Step()
assert(movementRoot.AssemblyLinearVelocity==idleVelocity,'idle movement does not inject velocity')
newHum.MoveDirection=MOCK.vec(1,0,0); movementRoot.Anchored=true; tools:Step()
assert(movementRoot.AssemblyLinearVelocity==idleVelocity,'anchored root ignored'); movementRoot.Anchored=false
newHum.Sit=true; tools:Step(); assert(movementRoot.AssemblyLinearVelocity==idleVelocity,'seated root ignored'); newHum.Sit=false
newHum.PlatformStand=true; tools:Step(); assert(movementRoot.AssemblyLinearVelocity==idleVelocity,'ragdoll ignored'); newHum.PlatformStand=false
option('Character_VelocitySpeed'):SetState(false); movementRoot.AssemblyLinearVelocity=MOCK.vec(7,-9,4); tools:Step()
assert(movementRoot.AssemblyLinearVelocity.X==7 and movementRoot.AssemblyLinearVelocity.Y==-9,'disable stops velocity writes')
-- Stamina discovery is bounded and never runs GC every frame.
assert(not c.InfiniteStamina,'stamina disabled by default')
option('Character_InfiniteStamina'):SetState(true)
assert(tools.StaminaStatus:find('getgc',1,true),'missing API status')
local stamina={S=24}; local empty={S=0}
local frozen=table.freeze({S=35})
local invalid={S='hello'}; local large={S=250}
local scans=0
getgc=function(includeTables)
    assert(includeTables,'include GC tables')
    scans+=1; return {stamina,empty,frozen,invalid,large,{S=0/0},function() end}
end
tools:RescanStamina(); tools:Step()
assert(scans==1 and stamina.S==100 and empty.S==100 and frozen.S==35 and invalid.S=='hello' and large.S==250,'only mutable numeric 0..100 S candidates updated')
for _=1,100 do stamina.S=10; tools:Step() end
assert(scans==1 and stamina.S==100,'cached refill without per-frame GC scan')
option('Character_InfiniteStamina'):SetState(false); stamina.S=40; tools:Step()
assert(stamina.S==40 and #tools.staminaTables==0,'disable stops refill and releases cache')
option('Character_InfiniteStamina'):SetState(true)
button('Save profile').callback(); option('Character_InfiniteStamina'):SetState(false)
button('Load profile').callback(); assert(c.InfiniteStamina,'stamina profile roundtrip')
local oldCharacter=players.LocalPlayer.Character
players.LocalPlayer.Character=nil; tools:Step(); assert(#tools.staminaTables==0,'character removal clears cache')
players.LocalPlayer.Character=oldCharacter; local beforeScan=scans; tools:Step()
assert(scans==beforeScan+1,'respawn rescans')
local many={}; for index=1,200 do many[index]={S=50} end
getgc=function() return many end
tools:RescanStamina(); tools:Step(); assert(#tools.staminaTables==128 and many[129].S==50,'bounded candidate cache')
getgc=function() error('unsupported') end
tools:RescanStamina(); tools:Step(); assert(tools.StaminaStatus:find('failed',1,true),'scan failure isolated')
getgc=function() return {stamina} end
tools:RescanStamina(); tools:Step()
option('World_ColorEnabled'):SetState(true); local colorEffect=tools.effects.ColorCorrection
option('Interaction_Instant'):SetState(true)
local connection=tools.connections[1]
app:Unload()
assert(newHum.WalkSpeed==16 and lighting.ClockTime==14 and colorEffect.Destroyed and prompt.HoldDuration==3,'unload restores world, character and interaction hold time')
assert(next(tools.prompts)==nil,'prompt cache released')
assert(not connection.Connected and next(tools.applied)==nil and next(tools.effects)==nil and #tools.staminaTables==0,'owned resources released')
stamina.S=12; tools:Step(); assert(stamina.S==12,'unloaded instance never refills')
print('PASS universal tools: property ownership, removed movement methods, velocity, lighting, effects, player priorities, spectate, profiles and lazy script launchers')
