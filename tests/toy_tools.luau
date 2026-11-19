local character=Instance.new('Model'); character.Parent=workspace
local hum=Instance.new('Humanoid'); hum.Parent=character; hum.Health=100; character.Children.Humanoid=hum
MOCK.players.LocalPlayer.Character=character
local backpack=Instance.new('Backpack'); backpack.Parent=MOCK.players.LocalPlayer
MOCK.players.LocalPlayer.FindFirstChildOfClass=function(_,name) if name=='Backpack' then return backpack end end
local tracks={}
function hum:LoadAnimation(animation)
    local track={Id=animation.AnimationId}
    function track:Play() self.Played=true end
    function track:Stop() self.Stopped=true end
    function track:Destroy() self.Destroyed=true end
    table.insert(tracks,track); return track
end
local app=assert(loadstring(SOURCES['main.lua']))()
local toys,s=app.ToyTools,app.Config.Fun
assert(not toys.tool,'disabled creates no Tool')
app.Library.options.Fun_Jerk:SetState(true)
assert(toys.tool and toys.tool.Parent==backpack and not toys.tool.RequiresHandle,'toggle creates handleless tool')
local tool=toys.tool; tool.Activated:Fire(); assert(tracks[1].Played and tracks[1].Looped and tracks[1].Id=='rbxassetid://72042024','R6 animation')
tool.Activated:Fire(); assert(tracks[1].Stopped and tracks[1].Destroyed,'activate again stops')
hum.RigType=Enum.HumanoidRigType.R15; tool.Activated:Fire(); assert(tracks[2].Id=='rbxassetid://698251653','R15 animation')
hum.Health=0; toys:Step(); assert(tracks[2].Stopped,'death stops'); hum.Health=100
local newCharacter=Instance.new('Model'); newCharacter.Parent=workspace; newCharacter.Children.Humanoid=hum
MOCK.players.LocalPlayer.Character=newCharacter; toys:Step(); assert(tool.Destroyed and toys.tool~=tool,'respawn replaces tool')
s.Jerk=false; toys:Step(); assert(not toys.tool,'disable removes tool')
s.Jerk=true; toys:Step(); toys.tool.Activated:Fire(); app:Unload()
assert(not toys.tool and tracks[#tracks].Stopped and not toys.heartbeat.Connected,'unload cleanup')
print('PASS Jerk Tool: R6/R15, activation toggle, death/respawn, disable and unload')
