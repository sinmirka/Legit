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
app:Unload()
assert(newHum.WalkSpeed==16 and next(tools.applied)==nil,'character cleanup')
print('PASS universal character controls, property ownership, respawn and jump')
