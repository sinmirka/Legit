local jumping=Enum.HumanoidStateType.Jumping
local function fixture()
    local char=Instance.new('Model')
    local hum=Instance.new('Humanoid'); hum.Health=100; hum.EnabledStates={}; hum.Parent=char
    hum.StateChanged=Instance.new('BindableEvent').Activated
    function hum:GetStateEnabled(state) return self.EnabledStates[state]~=false end
    function hum:SetStateEnabled(state,value) self.EnabledStates[state]=value end
    function hum:Enter(state)
        local old=self:GetState(); self.State=state; self.StateChanged:Fire(old,state)
    end
    char.Children.Humanoid=hum
    return char,hum
end
local char,hum=fixture(); MOCK.players.LocalPlayer.Character=char
local app=assert(loadstring(SOURCES['main.lua']))()
local tools,c=app.Tools,app.Config.Character
local now=1
tools.Now=function() return now end
assert(not c.JumpCooldown and not tools.jumpConnection,'disabled by default')
c.JumpDelay=0.5; app.Library.options.Character_JumpCooldown:SetState(true)
assert(hum:GetStateEnabled(jumping) and tools.JumpStatus=='Ready','first jump unrestricted')
hum:Enter(jumping); assert(not hum:GetStateEnabled(jumping),'actual jump starts cooldown immediately')
now=1.3; hum:Enter(Enum.HumanoidStateType.Landed); tools:Step()
assert(not hum:GetStateEnabled(jumping),'landing does not bypass cooldown')
now=1.51; tools:Step(); assert(hum:GetStateEnabled(jumping),'cooldown ends without another jump request')
hum:Enter(jumping); app.Library.options.Character_JumpCooldown:SetState(false)
assert(hum:GetStateEnabled(jumping) and not tools.jumpConnection,'disable restores enabled state and disconnects')
hum:Enter(Enum.HumanoidStateType.Running); hum:SetStateEnabled(jumping,false)
app.Library.options.Character_JumpCooldown:SetState(true); hum:Enter(jumping)
now=2.1; tools:Step(); assert(not hum:GetStateEnabled(jumping),'game-disabled jumping remains disabled')
hum:SetStateEnabled(jumping,true)
hum:Enter(jumping)
local oldConnection=tools.jumpConnection
local nextChar,nextHum=fixture(); MOCK.players.LocalPlayer.Character=nextChar; tools:Step()
assert(hum:GetStateEnabled(jumping) and not oldConnection.Connected and nextHum:GetStateEnabled(jumping),'respawn restores old and attaches new')
nextHum:Enter(jumping); local connection=tools.jumpConnection
app:Unload()
assert(nextHum:GetStateEnabled(jumping) and not connection.Connected,'unload restores and disconnects')
print('PASS jump limit: real jump timing, cooldown through landing, restore game state, disable, respawn and unload')
