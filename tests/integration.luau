local app=assert(loadstring(SOURCES['main.lua'],'@main.lua'))()
assert(app.Alive and app.Library.hasInit,'startup')
assert(#app.Library.windows==1,'one Tokyo window')
assert(#app.Library.windows[1].tabs==7,'seven settings tabs')
local count=0
for _ in pairs(app.Library.options) do count+=1 end
assert(count>=90,'expected extensive settings: '..count)
print('PASS actual Tokyo startup and '..count..' UI options')
local function option(name) return assert(app.Library.options[name],name) end
option('ESP_Enabled'):SetState(true)
option('ESP_FillOpacity'):SetValue(0.6)
option('Colors_Fill'):SetColor(Color3.fromRGB(10,20,30))
option('Colors_Fill'):SetTrans(0.25)
assert(app.Config.ESP.Enabled and app.Config.ESP.FillOpacity==0.6,'toggle/slider callbacks')
assert(app.Config.Colors.Fill.R==10/255 and app.Config.Alpha.Colors_Fill==0.75,'color and alpha callbacks')
option('Labels_Font'):Select('Monospace')
assert(app.Config.Labels.Font=='Monospace','font selection')
for _,tab in ipairs(app.Library.windows[1].tabs) do tab:Select() end
print('PASS tab switching and live toggle, slider, font, color and alpha changes')
local function button(label)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,item in ipairs(section.options) do if item.class=='button' and item.text==label then return item end end
    end end
    error('Missing button '..label)
end
button('Save profile').callback()
option('ESP_Enabled'):SetState(false)
option('Colors_Fill'):SetTrans(0.9)
button('Load profile').callback()
assert(app.Config.ESP.Enabled and math.abs(app.Config.Alpha.Colors_Fill-0.75)<1e-9,'profile roundtrip')
button('Reset defaults').callback()
assert(not app.Config.ESP.Enabled and app.Config.Alpha.Colors_Fill==1,'defaults')
print('PASS profile save/load including color alpha and reset')
option('Aim_Key'):SetBind(Enum.KeyCode.Backspace)
assert(app.Config.Aim.Key=='none','clear aim bind')
button('Save profile').callback()
option('Aim_Key'):SetBind(Enum.UserInputType.MouseButton2)
button('Load profile').callback()
assert(app.Config.Aim.Key=='none','unbound profile roundtrip')
button('Reset defaults').callback()
local Http=MOCK.services.HttpService
MOCK.files['Legit/Universal/configs/default.json']=Http:JSONEncode({version=1,settings={ESP_Enabled=true,Aim_Radius='invalid'}})
button('Load profile').callback()
assert(not app.Config.ESP.Enabled,'invalid profile must not partially apply')
option('profile_name'):SetInput('../outside')
button('Save profile').callback()
assert(not MOCK.files['Legit/Universal/configs/../outside.json'],'profile path traversal')
option('profile_name'):SetInput('default')
print('PASS invalid profile prevalidation and path restriction')

local Engine=assert(loadstring(SOURCES['src/Engine.lua'],'@Engine.lua'))()
local tested=Engine.new(app.Config,app.Library)
local function makePlayer(id,x)
    local other={UserId=id,Name='Player'..id,DisplayName='Player'..id,Neutral=false,Team={},Parent=MOCK.players,TeamColor={Color=Color3.new(1,0,0)}}
    local char=Instance.new('Model'); other.Character=char
    local function part(name,dx,dy,dz)
        local p=Instance.new('Part'); p.Name=name; p.Position=MOCK.vec(x+dx,dy,30+dz)
        p.AssemblyLinearVelocity=MOCK.vec(5,0,0); p.Parent=char; char.Children[name]=p
        return p
    end
    local root=part('HumanoidRootPart',0,0,0)
    part('Head',0,2,0); part('Torso',0,0,0)
    part('Left Arm',-2,0,0); part('Right Arm',2,0,0); part('Left Leg',-1,-2,0); part('Right Leg',1,-2,0)
    local humanoid=Instance.new('Humanoid'); humanoid.Health=100; humanoid.MaxHealth=100; char.Children.Humanoid=humanoid
    function char:GetBoundingBox() return CFrame.lookAt(root.Position,root.Position+MOCK.vec(0,0,1)),MOCK.vec(4,6,2) end
    return other,root,humanoid
end
local other,root,humanoid=makePlayer(2,10)
local other2,root2=makePlayer(3,40)
local localCharacter,localRoot=makePlayer(1,0)
MOCK.players.LocalPlayer.Character=localCharacter.Character
MOCK.players.list={MOCK.players.LocalPlayer,other,other2}
local camera=workspace.CurrentCamera
local a,e=app.Config.Aim,app.Config.ESP
assert(tested:Candidate(other,camera,localRoot),'valid candidate')
other.Team=MOCK.players.LocalPlayer.Team
assert(not tested:Candidate(other,camera,localRoot),'team check')
other.Neutral=true
assert(tested:Candidate(other,camera,localRoot),'neutral target')
other.Team={}; other.Neutral=false
tested.friends[other]=true; a.SkipFriends=true
assert(not tested:Candidate(other,camera,localRoot),'friends filter')
a.SkipFriends=false
a.Part='UpperTorso'
assert(tested:Candidate(other,camera,localRoot).Part.Name=='Torso','R6 fallback')
a.Part='LeftUpperArm'
assert(not tested:Candidate(other,camera,localRoot),'missing selected part')
a.Part='Head'
humanoid.Health=0; assert(not tested:Candidate(other,camera,localRoot),'dead target'); humanoid.Health=100
a.MaxDistance=5; assert(not tested:Candidate(other,camera,localRoot),'range filter'); a.MaxDistance=1000
a.Radius=5; assert(not tested:Candidate(other,camera,localRoot),'FOV filter'); a.Radius=160
workspace.Hit={Instance={IsDescendantOf=function() return false end}}
assert(not tested:Candidate(other,camera,localRoot),'wall filter')
a.WallCheck=false; assert(tested:Candidate(other,camera,localRoot),'wall filter off'); a.WallCheck=true; workspace.Hit=nil
a.Prediction=true; a.LeadTime=0.2
assert(math.abs(tested:Candidate(other,camera,localRoot).Position.X-11)<1e-9,'prediction')
a.Prediction=false
a.AcquireDelay=0.2
assert(not tested:Choose(camera,localRoot,0),'acquisition delay')
assert(not tested:Choose(camera,localRoot,0.1),'pending target')
assert(tested:Choose(camera,localRoot,0.21).Player==other,'acquisition completes')
other2.Character.Children.Head.Position=MOCK.vec(0,0,30)
assert(tested:Choose(camera,localRoot,1).Player==other,'sticky target')
a.Sticky=false; a.AcquireDelay=0; a.SwitchDelay=0
assert(tested:Choose(camera,localRoot,2).Player==other2,'screen priority')
a.Priority='Lowest health'; humanoid.Health=5
assert(tested:Choose(camera,localRoot,3).Player==other,'health priority')
humanoid.Health=100
a.Enabled=true; a.Mode='Hold'; tested.held=true
tested:Aim(camera,localRoot,1/60)
assert(not tested.target,'menu pauses aim')
app.Library:SetOpen(false)
tested:Aim(camera,localRoot,1/60)
assert(tested.target and camera.CFrame.LastAlpha and camera.CFrame.LastAlpha>0,'camera smoothing')
print('PASS teams, neutral, friends, R6, missing parts, death, range, FOV, walls, prediction, delay, sticky, priorities and aim pause')
e.Enabled=true; e.VisibleColors=true; e.TargetColor=false
app.Config.Alpha.Colors_VisibleFill=0.3
app.Config.Overlay.Box=true; app.Config.Overlay.BoxFill=true; app.Config.Overlay.Skeleton=true
app.Config.Overlay.Tracers=true; app.Config.Overlay.HealthBar=true
tested:ESP(camera,localRoot)
local record=assert(tested.records[other],'ESP record')
assert(record.Highlight.Enabled and record.TopText.Visible and record.HealthBar.Visible,'chams and labels')
assert(record.Corners[1].Visible and record.Fill.Visible and record.Tracer.Visible,'corner box and tracer')
assert(record.Bones[15].Visible,'R6 skeleton')
assert(math.abs(record.Highlight.FillTransparency-(1-e.FillOpacity*0.3))<1e-9,'per-color opacity')
app.Config.Overlay.BoxStyle='Full'; tested:ESP(camera,localRoot)
assert(record.Box.Visible and not record.Corners[1].Visible,'full box clears corners')
workspace.Hit={Instance={IsDescendantOf=function() return false end}}
e.ThroughWalls=false; tested:ESP(camera,localRoot)
assert(not record.Highlight.Enabled and not record.TopText.Visible,'occlusion hides ESP')
e.Enabled=false; workspace.Hit=nil; tested:ESP(camera,localRoot)
assert(not tested.records[other],'disabled ESP frees record')
tested:Destroy()
button('Reset defaults').callback()
print('PASS chams, per-color alpha, labels, corner/full boxes, skeleton, tracers, health bars, occlusion and resource cleanup')
for _,callback in pairs(MOCK.services.RunService.bindings) do callback(1/60) end
app:Unload()
for _,thread in ipairs(task.pending) do
    if coroutine.status(thread)=='suspended' then local resumed,problem=coroutine.resume(thread); assert(resumed,problem) end
end
table.clear(task.pending)
assert(not app.Alive and not getgenv().Legit and not getgenv().library,'unload globals')
for _,drawing in ipairs(DRAWINGS) do assert(drawing.Removed,'leaked Drawing') end
assert(next(MOCK.services.RunService.bindings)==nil,'leaked render binding')
app:Unload()
local second=assert(loadstring(SOURCES['main.lua'],'@main.lua'))()
local third=assert(loadstring(SOURCES['main.lua'],'@main.lua'))()
assert(not second.Alive and third.Alive,'repeat execution cleanup')
third:Unload()
print('PASS unload, idempotent cleanup, and repeat execution')
