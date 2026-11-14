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
option('Character_Speed'):SetValue(40); option('Character_WalkSpeed'):SetState(true)
assert(localHum.WalkSpeed==40,'speed UI applies immediately')
localHum.WalkSpeed=22; tools:Step(); assert(localHum.WalkSpeed==40,'speed stays enforced')
option('Character_WalkSpeed'):SetState(false); assert(localHum.WalkSpeed==22,'restore latest game baseline')
option('Character_JumpOverride'):SetState(true); option('Character_JumpPower'):SetValue(80)
assert(localHum.JumpPower==80,'jump power')
localHum.UseJumpPower=false; option('Character_JumpHeight'):SetValue(12)
assert(localHum.JumpPower==50 and localHum.JumpHeight==12,'respect game jump mode and restore old property')
option('Character_JumpOverride'):SetState(false); assert(localHum.JumpHeight==7.2,'restore jump height')
option('Character_Noclip'):SetState(true)
assert(not localRoot.CanCollide and not localHead.CanCollide,'noclip')
option('Character_Noclip'):SetState(false)
assert(localRoot.CanCollide and not localHead.CanCollide,'restore per-part original collisions')
c.WalkSpeed=true; c.Speed=35; tools:Step()
local newFixture,newHum=makePlayer(1,'Respawn')
players.LocalPlayer.Character=newFixture.Character; tools:Step()
assert(localHum.WalkSpeed==22 and newHum.WalkSpeed==35,'respawn restores old rig and applies to new rig')
option('Character_WalkSpeed'):SetState(false)
app.Library:SetOpen(false)
option('Character_InfiniteJump'):SetState(true)
MOCK.services.UserInputService.JumpRequest:Fire()
assert(newHum.LastState==Enum.HumanoidStateType.Jumping,'infinite jump signal')
newHum.LastState=nil; app.Engine.focused=false
MOCK.services.UserInputService.JumpRequest:Fire(); assert(not newHum.LastState,'infinite jump focus guard')
app.Engine.focused=true
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
option('World_TimeEnabled'):SetState(true); option('Character_WalkSpeed'):SetState(true)
button('Save profile').callback()
option('World_Time'):SetValue(8); option('Character_Speed'):SetValue(70)
button('Load profile').callback()
assert(lighting.ClockTime==3 and newHum.WalkSpeed==35,'universal profile roundtrip')
-- External launchers are lazy and tested with inert responses, never downloaded/executed here.
local clipboard
setclipboard=function(text) clipboard=text end
game.PlaceId=123; game.JobId='test-server'
button('Copy server info').callback()
assert(clipboard=='PlaceId: 123\nJobId: test-server','copy server information')
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
option('World_ColorEnabled'):SetState(true); local colorEffect=tools.effects.ColorCorrection
local connection=tools.connections[1]
app:Unload()
assert(newHum.WalkSpeed==16 and lighting.ClockTime==14 and colorEffect.Destroyed,'unload restores world and character')
assert(not connection.Connected and next(tools.applied)==nil and next(tools.effects)==nil,'owned resources released')
print('PASS universal tools: property ownership, respawn, jump, lighting, effects, player priorities, spectate, profiles and lazy script launchers')
