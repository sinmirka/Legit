local app=assert(loadstring(SOURCES['main.lua']))()
local silent,s=app.SilentAim,app.Config.Silent
local players,vec=MOCK.players,MOCK.vec
local function player(id,x,z)
    local p={UserId=id,Name='Ray'..id,DisplayName='Ray'..id,Parent=players,Neutral=false,Team={}}
    local char=Instance.new('Model'); char.Parent=workspace; p.Character=char
    local hum=Instance.new('Humanoid'); hum.Health=100; char.Children.Humanoid=hum
    for _,name in ipairs({'Head','HumanoidRootPart'}) do
        local part=Instance.new('Part'); part.Position=vec(x,0,z); part.Parent=char
        part.AssemblyLinearVelocity=vec(0,0,0); char.Children[name]=part
    end
    return p,char,hum
end
local fixture,character=player(1,0,0)
players.LocalPlayer.Character=character
local target,targetChar,hum=player(2,6,30)
players.list={players.LocalPlayer,target}
local method,executor='Raycast',false
local intercepted,params,result,lastArgs,fail
local installed,calls=0,0
hookmetamethod=function(_,name,fn)
    assert(name=='__namecall'); installed+=1; intercepted=fn
    return function(receiver,...)
        calls+=1; lastArgs=table.pack(...)
        if fail then error('game ray failure') end
        return result,nil,'tail',nil
    end
end
getnamecallmethod=function() return method end
checkcaller=function() return executor end
getcallingscript=function() return nil end -- Caller need not be a child of a known weapon.
newcclosure=function(fn) return fn end
hookfunction=nil -- Universal mode does not need the Criminality APIs.
app.Library:SetOpen(false)
assert(not s.Universal,'Criminality is the default')
s.Enabled=true; silent:Step(0)
assert(not silent.prepared and installed==0,'Criminality remains unavailable without its API')
app.Library.options.Silent_Universal:SetState(true)
silent:Step(1)
assert(installed==1 and silent.prepared and silent.Backend=='Universal Raycast','generic mode without gun or game modules')
local origin,direction=vec(0,0,0),vec(0,0,100)
params={FilterType=Enum.RaycastFilterType.Exclude,FilterDescendantsInstances={character}}
local function cast(receiver)
    local before=calls
    local a,b,c,d=intercepted(receiver or workspace,origin,direction,params,nil,'extra',nil)
    assert(calls==before+1 and a==result and b==nil and c=='tail' and d==nil,'original runs once and keeps results')
    assert(lastArgs.n==6 and lastArgs[3]==params and lastArgs[4]==nil and lastArgs[5]=='extra','params and nil args retained')
    return lastArgs[2]
end
result={Instance=targetChar.Children.Head,Position=vec(6,0,30)}
local sent=cast()
assert(sent.X>0 and math.abs(sent.Magnitude-100)<1e-8,'hitscan direction changes without extending range')
assert(silent.traceQueue[1].End==result.Position and silent.traceQueue[1].Hit,'trace uses actual ray result')
silent:Render(os.clock())
assert(silent.tracePool[1].To.Position==result.Position,'universal trace rendered in world')
executor=true; assert(cast()==direction,'executor visibility rays ignored'); executor=false
method='FindPartOnRay'; assert(cast()==direction,'unsupported API passed through'); method='Raycast'
assert(cast({})==direction,'other receivers passed through')
origin=vec(200,0,0); assert(cast()==direction,'distant player rays ignored'); origin=vec(0,0,0)
direction=vec(0,0,1); assert(cast()==direction,'short ray cannot reach selected target'); direction=vec(0,0,100)
s.HitChance=0; assert(cast()==direction,'chance respected'); s.HitChance=100
hum.Health=0; assert(cast()==direction,'target death effective before refresh'); hum.Health=100
hum.Health=15; hum.PlatformStand=true; assert(cast()==direction,'new downed state respected')
hum.PlatformStand=false; hum.Health=100
local gun=Instance.new('Tool'); gun.Name='Unknown Weapon'; gun.Enabled=true; gun.Parent=character
character.Children.Tool=gun; silent:Step(2)
assert(cast()~=direction,'unknown tool without ammo accepted')
gun.Name='Fists'; silent:Step(3); assert(cast()~=direction,'universal mode has no supported weapon filter')
result=nil; silent.nextUniversalTrace=0; cast()
assert(not silent.traceQueue[#silent.traceQueue].Hit,'miss has no fabricated hit')
fail=true; local ok,problem=pcall(cast)
assert(not ok and tostring(problem):find('game ray failure',1,true),'game errors propagate'); fail=false
local redirect=silent.Redirect
silent.Redirect=function() error('adapter failure') end
assert(cast()==direction,'adapter error passes original ray through'); silent.Redirect=redirect
s.Universal=false; assert(cast()==direction,'mode switch stops redirect immediately')
silent:Step(4); assert(not silent.prepared and silent.raycastHook.SilentOwner==nil,'Criminality filters restored')
s.Universal=true; silent:Step(5); assert(installed==1 and cast()~=direction,'switch reuses shared hook')
app.Library:SetOpen(true); silent:Step(6); assert(cast()==direction,'menu pause')
app.Library:SetOpen(false); silent:Step(7)
s.Radius=1; silent:Step(8); assert(cast()==direction,'FOV filtering'); s.Radius=160
local positions={}
for _,part in ipairs(targetChar:GetChildren()) do
    if part:IsA('BasePart') then positions[part]=part.Position; part.Position=vec(6,0,-30) end
end
silent:Step(8.1); assert(cast()==direction and not silent.prepared,'normal silent excludes targets behind camera')
app.Library.options.Silent_Full360:SetState(true); s.Radius=1; silent:Step(8.2)
assert(silent.prepared.Target.Player==target and cast().Z<0,'360 redirects behind camera independently of FOV')
assert(not silent.circle.Visible and silent.Status:find('360',1,true),'360 status and no misleading FOV circle')
assert(not app.Engine:Candidate(target,workspace.CurrentCamera,character.Children.HumanoidRootPart,app.Config.Aim),'camera aim still requires screen target')
local autoShots=0
mouse1click=function() autoShots+=1 end
s.AutoFire=true; s.AutoFireMethod='Mouse'; silent:Step(8.4)
assert(autoShots==1,'auto fire detects rear target in 360 mode')
s.AutoFire=false; s.MaxDistance=10; silent:Step(8.5)
assert(not silent.prepared and cast()==direction,'360 retains maximum range')
s.MaxDistance=1000; workspace.Hit={Instance={IsDescendantOf=function() return false end}}
silent:Step(8.6); assert(not silent.prepared,'360 retains wall filter'); workspace.Hit=nil
hum.PlatformStand=true; hum.Health=15; silent:Step(8.7); assert(not silent.prepared,'360 retains downed filter')
hum.PlatformStand=false; hum.Health=100
app.Engine.playerModes[target.UserId]='Friend'; silent:Step(8.8); assert(not silent.prepared,'360 retains friend filter')
app.Engine.playerModes[target.UserId]=nil
s.Full360=false; silent:Step(8.9); assert(not silent.prepared,'turning 360 off restores screen filtering')
for part,position in pairs(positions) do part.Position=position end
s.Radius=160; s.Full360=true
local function button(label)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,option in ipairs(section.options) do if option.class=='button' and option.text==label then return option end end
    end end
end
button('Save profile').callback(); app.Library.options.Silent_Universal:SetState(false)
app.Library.options.Silent_Full360:SetState(false)
button('Load profile').callback(); assert(s.Universal and s.Full360,'universal and 360 modes persist in profile')
silent:Step(9)
local state=silent.raycastHook
app:Unload(); assert(state.SilentOwner==nil and cast()==direction,'unload releases universal owner')
local nextApp=assert(loadstring(SOURCES['main.lua']))()
nextApp.Library:SetOpen(false); nextApp.Config.Silent.Enabled=true; nextApp.Config.Silent.Universal=true
nextApp.SilentAim:Step(10)
assert(installed==1 and state.SilentOwner==nextApp.SilentAim,'reload reuses shared dispatcher')
hookmetamethod=nil; nextApp.SilentAim:Step(11)
assert(not nextApp.SilentAim.prepared and nextApp.SilentAim.Status:find('hookmetamethod',1,true),'missing API is explicit')
nextApp:Unload()
print('PASS universal silent: any/no weapon, no Criminality modules, real ray results, range, filtering, switching, errors, world traces, profiles and reload')
