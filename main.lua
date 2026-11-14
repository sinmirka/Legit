-- Legit | Obsidian UI. Entry point for the README loadstring.
local bundledFiles=...
local BASE='https://raw.githubusercontent.com/sinmirka/Legit/main/'
-- BEGIN HTTP TRANSPORT
-- Used by main.lua and the standalone loader.lua; never compile an unchecked body.
local function download(path)
    if type(bundledFiles)=='table' then
        assert(type(bundledFiles[path])=='string','[Legit bundle] Missing embedded file: '..path)
        return bundledFiles[path]
    end
    local bases={
        'https://raw.githubusercontent.com/sinmirka/Legit/main/',
        'https://cdn.jsdelivr.net/gh/sinmirka/Legit@main/',
    }
    local methods,seen={},{}
    local function add(name,callback)
        if type(callback)=='function' and not seen[callback] then
            seen[callback]=true
            table.insert(methods,{Name=name,Get=function(url)
                return callback({Url=url,Method='GET',Timeout=15})
            end})
        end
    end
    add('request',request)
    add('http_request',http_request)
    add('syn.request',type(syn)=='table' and syn.request)
    add('http.request',type(http)=='table' and http.request)
    table.insert(methods,{Name='HttpGet',Get=function(url) return game:HttpGet(url,true) end})
    local failures={}
    for index,base in ipairs(bases) do
        for _,method in ipairs(methods) do
            local ok,result=pcall(method.Get,base..path)
            local body,problem=result,nil
            if ok and type(result)=='table' then
                local status=tonumber(result.StatusCode or result.Status)
                if result.Success==false or (status and (status<200 or status>=300)) then
                    problem='HTTP '..tostring(status or 'failure')
                end
                body=result.Body
            end
            if not ok then problem=tostring(result)
            elseif not problem then
                if type(body)~='string' then problem='expected response text, got '..type(body)
                elseif not body:find('%S') then problem='empty response'
                elseif path:match('%.png$') and body:sub(1,8)~='\137PNG\r\n\26\n' then problem='invalid PNG response'
                elseif not path:match('%.png$') and body:match('^%s*<') then problem='HTML response instead of Lua' end
            end
            if not problem then return body end
            table.insert(failures,('source %d / %s: %s'):format(index,method.Name,problem))
        end
    end
    error('[Legit HTTP] '..path..' could not be downloaded. '..table.concat(failures,' | '),0)
end
-- END HTTP TRANSPORT
assert(type(loadstring)=='function','Legit needs loadstring support')
assert(type(getgenv)=='function','Legit needs getgenv support')
for _,name in ipairs({'makefolder','isfile','readfile','writefile'}) do
    assert(type(getfenv()[name])=='function','Legit profiles require '..name)
end
if not game:IsLoaded() then game.Loaded:Wait() end
local env=getgenv()
if env.Legit and env.Legit.Unload then
    local previous=env.Legit
    if previous.Library and previous.Library.drawings then
        for object in pairs(previous.Library.drawings) do pcall(function() object.Visible=false end) end
    end
    local cleaned,problem=pcall(previous.Unload,previous)
    if not cleaned then
        warn('[Legit] Previous version cleanup: '..tostring(problem))
        if previous.Library and previous.Library.drawings then
            for object in pairs(previous.Library.drawings) do pcall(function() object.Visible=false end) end
        end
    end
    env.Legit=nil
end
local function remote(path)
    local source=download(path)
    local chunk,message=loadstring(source,'@Legit/'..path)
    assert(chunk,'Legit compile failed: '..path..' / '..tostring(message))
    return chunk
end
local renderMode='GUI'
local renderer=remote('src/GuiDrawing.lua')().new(game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui'))
local drawingAPI=renderer
local loaded,library=pcall(function()
    local icons=remote('vendor/Obsidian/Lucide.lua')()
    local obsidian=remote('vendor/Obsidian/Library.lua')(icons)
    return remote('src/ObsidianUI.lua')().new(obsidian)
end)
if not loaded then if renderer then renderer:Destroy() end; error('[Legit] '..tostring(library),0) end
library.toggleKey=Enum.KeyCode.RightShift
library.theme=table.clone(library.themes[1].theme)
local config={
    Alpha={},Interface={Accent=library.theme.Accent,MenuKey=Enum.KeyCode.RightShift,Scale=100},
    Debug={Enabled=false,Console=false,CaptureRays=false},
    Character={WalkSpeed=false,Speed=16,JumpOverride=false,JumpPower=50,JumpHeight=7.2,Noclip=false,InfiniteJump=false},
    World={TimeEnabled=false,Time=12,ExposureEnabled=false,Exposure=0,AmbientEnabled=false,
        Ambient=Color3.fromRGB(128,128,128),RemoveShadows=false,BloomEnabled=false,BloomIntensity=0.5,
        BloomSize=24,BloomThreshold=1,ColorEnabled=false,Brightness=0,Contrast=0,Saturation=0,
        Tint=Color3.new(1,1,1),AtmosphereEnabled=false,Density=0.3,Haze=0,AtmosphereColor=Color3.new(1,1,1)},
    ESP={
        Enabled=false,Chams=true,Outline=true,ThroughWalls=true,TeamCheck=false,SkipFriends=false,
        MaxDistance=1500,RefreshRate=30,Opacity=1,FillOpacity=0.35,OutlineOpacity=1,
        VisibleColors=false,TeamColors=false,TargetColor=true,Rainbow=false,RainbowSpeed=0.15,
        Fade=false,FadeStart=0.6,Pulse=false,PulseSpeed=1,
    },
    Colors={
        Fill=Color3.fromRGB(145,105,245),Outline=Color3.fromRGB(225,215,255),
        VisibleFill=Color3.fromRGB(90,220,150),VisibleOutline=Color3.fromRGB(140,255,190),
        HiddenFill=Color3.fromRGB(235,85,120),HiddenOutline=Color3.fromRGB(255,155,175),
        Target=Color3.fromRGB(255,205,90),Box=Color3.fromRGB(195,175,255),
        Tracer=Color3.fromRGB(175,150,255),Skeleton=Color3.fromRGB(235,230,255),
        Text=Color3.fromRGB(245,245,250),TextOutline=Color3.new(0,0,0),
        HealthLow=Color3.fromRGB(255,70,85),HealthHigh=Color3.fromRGB(80,235,130),
    },
    Overlay={
        Box=false,BoxStyle='Corners',Thickness=1,BlackOutline=true,MatchESP=true,
        CornerLength=0.25,BoxFill=false,FillOpacity=0.08,
        Tracers=false,TracerOrigin='Bottom',TracerThickness=1,
        Skeleton=false,SkeletonThickness=1,HealthBar=false,HealthWidth=3,
    },
    Labels={Enabled=true,Names=true,NameMode='Both',Health=true,Distance=true,Tool=false,Team=false,
        Size=13,Font='Plex',TextOutline=true,Opacity=1,Offset=0},
    Melee={Enabled=false,AutoAttack=true,Range=10,Interval=0.5,SwingWindow=0.35,
        Part='Head',Priority='Distance',TeamCheck=false,SkipFriends=false,
        SkipForceField=true,WallCheck=true,MinHealth=1,PauseMenu=true,SkipDowned=true},
    Silent={Enabled=false,Part='Head',Priority='Screen',TeamCheck=false,SkipFriends=false,
        SkipForceField=true,SkipDowned=true,WallCheck=true,MinHealth=1,MaxDistance=1000,Radius=160,
        HitChance=100,ShowFOV=true,FOVColor=Color3.fromRGB(255,215,90),FOVOpacity=0.7,
        Prediction=false,LeadTime=0.1,OffsetX=0,OffsetY=0,OffsetZ=0,PauseMenu=true,OriginRadius=12,
        ShowTracers=true,ShowOriginalRay=true,ShowTargetGuide=true,TraceDuration=1,TraceThickness=2},
    Aim={
        Enabled=false,Key=Enum.UserInputType.MouseButton2,Mode='Hold',Part='Head',
        TeamCheck=false,SkipFriends=false,SkipForceField=false,WallCheck=true,MinHealth=1,
        MaxDistance=1000,Radius=160,ShowFOV=true,FOVOpacity=0.7,FOVThickness=1,
        FOVColor=Color3.fromRGB(155,120,255),TargetColor=Color3.fromRGB(255,205,90),
        TargetLine=false,ShowDeadzone=false,Deadzone=0,
        Smoothing='Exponential',Speed=12,Axis='Both',Sticky=true,Priority='Screen',
        AcquireDelay=0,SwitchDelay=0.15,OffsetX=0,OffsetY=0,OffsetZ=0,
        Prediction=false,LeadTime=0.1,PauseMenu=false,SkipScriptable=false,
    },
}
local engine,melee,silent,tools,logger
local app={Library=library,Config=config,Alive=true,Renderer=renderMode,DrawingRenderer=renderer}
function app:DebugContext()
    local character=game:GetService('Players').LocalPlayer.Character
    local equipped=character and character:FindFirstChildOfClass('Tool')
    local data={AimStatus=engine and engine.Status or 'not started',MeleeStatus=melee and melee.Status or 'not started',
        MeleeEnabled=config.Melee.Enabled,AutoAttack=config.Melee.AutoAttack,Range=config.Melee.Range,
        Interval=config.Melee.Interval,SwingWindow=config.Melee.SwingWindow,PauseMenu=config.Melee.PauseMenu,SkipDowned=config.Melee.SkipDowned,
        EquippedTool=equipped and equipped.Name or 'none',DiagnosticsEnabled=config.Debug.Enabled}
    if melee then for key,value in pairs(melee.Counters) do data['Melee.'..key]=value end end
    data.SilentStatus=silent and silent.Status or 'not started'
    data.SilentEnabled=config.Silent.Enabled
    data.SilentPart=config.Silent.Part; data.SilentFOV=config.Silent.Radius
    data.SilentHitChance=config.Silent.HitChance; data.SilentMaxDistance=config.Silent.MaxDistance
    if silent then for key,value in pairs(silent.Counters) do data['Silent.'..key]=value end end
    return data
end
function app:Unload()
    if not self.Alive then return end
    self.Alive=false
    if env.Legit==self then env.Legit=nil end
    if logger then logger:Write('info','App','unload','Unloading Legit') end
    local function clean(label,callback)
        local success,problem=pcall(callback)
        if not success then warn('[Legit cleanup / '..label..'] '..tostring(problem)) end
    end
    if tools then clean('universal tools',function() tools:Destroy() end) end
    if silent then clean('silent aim',function() silent:Destroy() end) end
    if melee then clean('melee',function() melee:Destroy() end) end
    if engine then clean('engine',function() engine:Destroy() end) end
    clean('UI',function() library:Unload() end)
    if renderer then clean('renderer',function() renderer:Destroy() end) end
end
env.Legit=app
local ok,message=xpcall(function()
    library:init()
    logger=remote('src/Diagnostics.lua')().new(config.Debug)
    app.Logger=logger
    local Engine=remote('src/Engine.lua')()
    engine=Engine.new(config,library,drawingAPI)
    engine.Logger=logger
    app.Engine=engine
    melee=remote('src/MeleeAura.lua')().new(config.Melee,engine,library)
    app.MeleeAura=melee
    silent=remote('src/SilentAim.lua')().new(config.Silent,engine,library,melee)
    app.SilentAim=silent
    tools=remote('src/UniversalTools.lua')().new(config,engine,library)
    app.Tools=tools
    library.unloaded:Connect(function()
        if silent then pcall(silent.Destroy,silent) end
        if tools then pcall(tools.Destroy,tools) end
        if melee then pcall(melee.Destroy,melee) end
        if engine then pcall(engine.Destroy,engine) end
        if renderer then renderer:Destroy() end
        app.Alive=false
        if env.Legit==app then env.Legit=nil end
    end)
    local camera=workspace.CurrentCamera
    local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
    local window=library.NewWindow({
        title='Criminality Legit',size=UDim2.fromOffset(920,700),
        position=UDim2.fromOffset(math.max(10,(viewport.X-660)/2),math.max(10,(viewport.Y-680)/2)),
    })
    local registered={}
    local function refreshTools(group)
        if group=='Character' or group=='World' then tools:Step() end
    end
    local function flag(group,key) return group..'_'..key end
    local function remember(group,key,option,kind,choices)
        registered[#registered+1]={Group=group,Key=key,Option=option,Kind=kind,Choices=choices,Default=config[group][key]}
        return option
    end
    local function toggle(section,label,group,key)
        local option=section:AddToggle({text=label,flag=flag(group,key),state=config[group][key],callback=function(value)
            config[group][key]=value
            refreshTools(group)
            if group=='Silent' then silent:Reset() end
            if group=='Silent' and key=='Enabled' and value then
                local unavailable=melee:CapabilityProblem()
                if unavailable then silent:SetStatus(unavailable); library:SendNotification(unavailable,7) end
            end
            if group=='Melee' then melee:Reset() end
            if group=='Melee' and key=='Enabled' and value then
                local unavailable=melee:CapabilityProblem()
                if unavailable then melee:StatusTo(unavailable); library:SendNotification(unavailable,7) end
            end
            if group=='Aim' and (key=='Enabled' or key=='PauseMenu') then engine.toggled=false; engine:ResetTarget() end
        end})
        return remember(group,key,option,'toggle')
    end
    local function slider(section,label,group,key,min,max,step,suffix)
        return remember(group,key,section:AddSlider({text=label,flag=flag(group,key),value=config[group][key],min=min,max=max,
            increment=step or 1,suffix=suffix or '',callback=function(value)
                config[group][key]=value
                refreshTools(group)
                if group=='Silent' then silent:Reset() end
                if group=='Melee' then melee:Reset() end
                if group=='Interface' and key=='Scale' then library.Obsidian:SetDPIScale(value) end
            end}),'slider')
    end
    local function select(section,label,group,key,choices)
        local option=section:AddList({text=label,flag=flag(group,key),selected=config[group][key],values=choices,callback=function(value)
            config[group][key]=value
            refreshTools(group)
            if group=='Silent' then silent:Reset() end
            if group=='Melee' then melee:Reset() end
            if group=='Aim' then engine.held=false; engine.toggled=false; engine:ResetTarget() end
        end})
        option:Select(config[group][key],true)
        return remember(group,key,option,'list',choices)
    end
    local function color(section,label,group,key)
        return remember(group,key,section:AddColor({text=label,flag=flag(group,key),color=config[group][key],callback=function(value,transparency)
            config[group][key]=value
            refreshTools(group)
            config.Alpha[flag(group,key)]=1-transparency
            if group=='Interface' then library.theme.Accent=value; library:SetTheme(library.theme) end
        end}),'color')
    end
    local tabs={}
    for _,name in ipairs({'Aimbot','Combat','Character','ESP','Misc','Players','UI Settings'}) do
        tabs[name]=window:AddTab(name)
    end
    local routes={Aim='Aimbot',['Aim+']='Aimbot',Colors='ESP',Overlay='ESP',Labels='ESP',Melee='Combat',Profiles='UI Settings'}
    local function sections(name,left,right)
        local tab=tabs[routes[name] or name]
        return tab:AddSection(left,1),tab:AddSection(right,2)
    end
    local left,right=sections('Aim','Activation','Target filters')
    toggle(left,'Enable aimbot','Aim','Enabled')
    select(left,'Activation mode','Aim','Mode',{'Hold','Toggle','Always'})
    local bind=left:AddBind({text='Aim key',flag='Aim_Key',bind=config.Aim.Key,noindicator=true,keycallback=function(key)
        config.Aim.Key=key; engine.held=false; engine.toggled=false; engine:ResetTarget()
    end})
    remember('Aim','Key',bind,'bind')
    select(left,'Body part','Aim','Part',{'Head','UpperTorso','LowerTorso','HumanoidRootPart','LeftUpperArm','RightUpperArm','LeftUpperLeg','RightUpperLeg'})
    select(left,'Priority','Aim','Priority',{'Screen','Distance','Lowest health'})
    toggle(left,'Keep current target','Aim','Sticky')
    slider(left,'Acquire delay','Aim','AcquireDelay',0,1.5,0.01,' s')
    slider(left,'Min switch interval','Aim','SwitchDelay',0,2,0.01,' s')
    toggle(left,'Pause while menu is open','Aim','PauseMenu')
    toggle(left,'Skip scriptable cameras','Aim','SkipScriptable')
    toggle(right,'Skip teammates','Aim','TeamCheck')
    toggle(right,'Skip Roblox friends','Aim','SkipFriends')
    toggle(right,'Skip ForceField','Aim','SkipForceField')
    toggle(right,'Visibility raycast','Aim','WallCheck')
    slider(right,'Minimum health','Aim','MinHealth',0,100,1)
    slider(right,'Maximum distance','Aim','MaxDistance',50,5000,10,' studs')
    slider(right,'FOV radius','Aim','Radius',10,800,1,' px')
    slider(right,'Deadzone radius','Aim','Deadzone',0,150,1,' px')
    left,right=sections('Aim+','Camera movement','FOV appearance')
    select(left,'Smoothing','Aim','Smoothing',{'Exponential','Instant'})
    slider(left,'Speed (higher = faster)','Aim','Speed',1,50,0.5)
    select(left,'Axes','Aim','Axis',{'Both','Horizontal','Vertical'})
    slider(left,'World offset X','Aim','OffsetX',-5,5,0.05,' studs')
    slider(left,'World offset Y','Aim','OffsetY',-5,5,0.05,' studs')
    slider(left,'World offset Z','Aim','OffsetZ',-5,5,0.05,' studs')
    toggle(left,'Velocity prediction','Aim','Prediction')
    slider(left,'Prediction time','Aim','LeadTime',0,0.4,0.005,' s')
    toggle(right,'Show FOV','Aim','ShowFOV')
    toggle(right,'Show deadzone','Aim','ShowDeadzone')
    toggle(right,'Line to target','Aim','TargetLine')
    color(right,'FOV color','Aim','FOVColor')
    color(right,'Locked target color','Aim','TargetColor')
    slider(right,'FOV opacity','Aim','FOVOpacity',0,1,0.01)
    slider(right,'FOV thickness','Aim','FOVThickness',1,5,0.5,' px')
    left,right=sections('ESP','Players and rendering','Chams and outline')
    toggle(left,'Enable ESP','ESP','Enabled')
    toggle(left,'Through walls','ESP','ThroughWalls')
    toggle(left,'Skip teammates','ESP','TeamCheck')
    toggle(left,'Skip Roblox friends','ESP','SkipFriends')
    slider(left,'Maximum distance','ESP','MaxDistance',50,5000,10,' studs')
    slider(left,'Refresh rate','ESP','RefreshRate',5,60,1,' Hz')
    slider(left,'Global opacity','ESP','Opacity',0,1,0.01)
    toggle(left,'Fade with distance','ESP','Fade')
    slider(left,'Fade starts at fraction','ESP','FadeStart',0,0.95,0.01)
    toggle(right,'Chams / character fill','ESP','Chams')
    toggle(right,'Character outline','ESP','Outline')
    slider(right,'Fill opacity','ESP','FillOpacity',0,1,0.01)
    slider(right,'Outline opacity','ESP','OutlineOpacity',0,1,0.01)
    toggle(right,'Visible / hidden colors','ESP','VisibleColors')
    toggle(right,'Use team colors','ESP','TeamColors')
    toggle(right,'Override current target color','ESP','TargetColor')
    toggle(right,'Rainbow colors','ESP','Rainbow')
    slider(right,'Rainbow cycles per second','ESP','RainbowSpeed',0.01,1,0.01)
    toggle(right,'Pulse opacity','ESP','Pulse')
    slider(right,'Pulse cycles per second','ESP','PulseSpeed',0.1,5,0.1)
    left,right=sections('Colors','Character colors','Overlay colors')
    for _,item in ipairs({{'Fill','Base fill'},{'Outline','Base outline'},{'VisibleFill','Visible fill'},
        {'VisibleOutline','Visible outline'},{'HiddenFill','Hidden fill'},{'HiddenOutline','Hidden outline'},{'Target','Current target'}}) do
        color(left,item[2],'Colors',item[1])
    end
    for _,item in ipairs({{'Box','Box'},{'Tracer','Tracers'},{'Skeleton','Skeleton'},{'Text','Labels'},
        {'TextOutline','Label outline'},{'HealthLow','Low health'},{'HealthHigh','Full health'}}) do
        color(right,item[2],'Colors',item[1])
    end
    left,right=sections('Overlay','2D boxes','Skeleton, lines and health')
    toggle(left,'Boxes','Overlay','Box')
    select(left,'Box style','Overlay','BoxStyle',{'Full','Corners'})
    slider(left,'Box thickness','Overlay','Thickness',1,5,0.5,' px')
    toggle(left,'Black box outline','Overlay','BlackOutline')
    toggle(left,'Match character color','Overlay','MatchESP')
    slider(left,'Corner length fraction','Overlay','CornerLength',0.1,0.5,0.01)
    toggle(left,'Fill box background','Overlay','BoxFill')
    slider(left,'Box fill opacity','Overlay','FillOpacity',0,0.5,0.01)
    toggle(right,'Skeleton','Overlay','Skeleton')
    slider(right,'Skeleton thickness','Overlay','SkeletonThickness',1,5,0.5,' px')
    toggle(right,'Tracers','Overlay','Tracers')
    select(right,'Tracer origin','Overlay','TracerOrigin',{'Bottom','Center','Top'})
    slider(right,'Tracer thickness','Overlay','TracerThickness',1,5,0.5,' px')
    toggle(right,'Health bar','Overlay','HealthBar')
    slider(right,'Health bar width','Overlay','HealthWidth',1,8,1,' px')
    left,right=sections('Labels','Information','Text appearance')
    toggle(left,'Enable labels','Labels','Enabled')
    toggle(left,'Names','Labels','Names')
    select(left,'Name format','Labels','NameMode',{'Display name','Username','Both'})
    toggle(left,'Health numbers','Labels','Health')
    toggle(left,'Distance','Labels','Distance')
    toggle(left,'Equipped tool','Labels','Tool')
    toggle(left,'Team name','Labels','Team')
    slider(right,'Font size','Labels','Size',10,24,1,' px')
    select(right,'Drawing font','Labels','Font',{'UI','System','Plex','Monospace'})
    toggle(right,'Text outline','Labels','TextOutline')
    slider(right,'Text opacity','Labels','Opacity',0,1,0.01)
    slider(right,'Text offset','Labels','Offset',0,30,1,' px')
    left,right=sections('Melee','Melee Aura / Melee Assist','Melee filters')
    toggle(left,'Enable melee aura','Melee','Enabled')
    toggle(left,'Auto attack','Melee','AutoAttack')
    slider(left,'Reach','Melee','Range',1,20,0.5,' studs')
    slider(left,'Attack interval','Melee','Interval',0.1,3,0.05,' s')
    slider(left,'Raycast swing window','Melee','SwingWindow',0.05,1,0.05,' s')
    select(left,'Hit part','Melee','Part',{'Head','UpperTorso','HumanoidRootPart'})
    select(left,'Target priority','Melee','Priority',{'Distance','Lowest health'})
    toggle(left,'Pause while menu is open','Melee','PauseMenu')
    left:AddText({text='Equip melee; disable Auto attack for manual swings'})
    left:AddButton({text='Show melee status',callback=function() library:SendNotification(melee.Status,5) end})
    toggle(right,'Skip teammates','Melee','TeamCheck')
    toggle(right,'Skip Roblox friends','Melee','SkipFriends')
    toggle(right,'Skip ForceField','Melee','SkipForceField')
    toggle(right,'Skip downed / ragdolled','Melee','SkipDowned')
    toggle(right,'Check walls','Melee','WallCheck')
    slider(right,'Minimum target HP','Melee','MinHealth',1,100,1)
    right:AddText({text='Requires executor Raycast hook APIs'})
    right:AddText({text='Game weapon cooldowns still apply'})
    local silentControls=tabs.Aimbot:AddSection('Silent Aim',2)
    toggle(silentControls,'Enable silent aim','Silent','Enabled')
    select(silentControls,'Silent target part','Silent','Part',{'Head','UpperTorso','HumanoidRootPart'})
    select(silentControls,'Silent priority','Silent','Priority',{'Screen','Distance','Lowest health'})
    slider(silentControls,'Hit chance per ray','Silent','HitChance',0,100,1,' %')
    slider(silentControls,'Silent FOV','Silent','Radius',10,800,1,' px')
    slider(silentControls,'Silent max distance','Silent','MaxDistance',50,5000,10,' studs')
    toggle(silentControls,'Show silent FOV','Silent','ShowFOV')
    color(silentControls,'Silent FOV color','Silent','FOVColor')
    slider(silentControls,'Silent FOV opacity','Silent','FOVOpacity',0,1,0.01)
    toggle(silentControls,'Silent wall check','Silent','WallCheck')
    toggle(silentControls,'Silent skip downed','Silent','SkipDowned')
    toggle(silentControls,'Silent skip teammates','Silent','TeamCheck')
    toggle(silentControls,'Silent skip friends','Silent','SkipFriends')
    toggle(silentControls,'Silent skip ForceField','Silent','SkipForceField')
    toggle(silentControls,'Silent pause with menu','Silent','PauseMenu')
    toggle(silentControls,'Silent prediction','Silent','Prediction')
    slider(silentControls,'Silent prediction time','Silent','LeadTime',0,0.4,0.005,' s')
    slider(silentControls,'Silent minimum HP','Silent','MinHealth',1,100,1)
    toggle(silentControls,'Show silent shot traces','Silent','ShowTracers')
    toggle(silentControls,'Show original ray direction','Silent','ShowOriginalRay')
    toggle(silentControls,'Show silent target guide','Silent','ShowTargetGuide')
    slider(silentControls,'Shot trace lifetime','Silent','TraceDuration',0.2,3,0.1,' s')
    slider(silentControls,'Shot trace thickness','Silent','TraceThickness',1,4,0.5,' px')
    silentControls:AddText({text='Cyan: redirected; orange: unchanged; grey: original; gold: target guide.'})
    silentControls:AddButton({text='Show silent status',callback=function() library:SendNotification(silent.Status,5) end})
    silentControls:AddText({text='Equip a gun and fire normally. Camera aim is independent.'})
    tabs.Combat:AddSection('Combat',1):AddText({text='Recoil, wallbang, auto-block and event combat are not implemented.'})
    tabs.Character:AddSection('Character',1):AddText({text='Game-specific stamina, fall damage and ragdoll changes are not included.'})
    tabs.ESP:AddSection('Values / Misc ESP',2):AddText({text='Game-specific loot, dealers and infection ESP are not included.'})
    left,right=sections('Character','Character / Universal','Speed options')
    toggle(left,'Noclip','Character','Noclip')
    toggle(left,'Infinite jump','Character','InfiniteJump')
    toggle(left,'Override jump','Character','JumpOverride')
    slider(left,'Jump power','Character','JumpPower',0,150,1)
    slider(left,'Jump height','Character','JumpHeight',0,30,0.1,' studs')
    toggle(right,'Walk speed','Character','WalkSpeed')
    slider(right,'Speed value','Character','Speed',0,150,1)
    right:AddText({text='Jump power or height follows the game jump mode.'})
    right:AddText({text='Server movement limits can still apply.'})
    left,right=sections('ESP','World','World effects')
    toggle(left,'Time changer','World','TimeEnabled')
    slider(left,'Select hours','World','Time',0,24,0.1)
    toggle(left,'Custom exposure','World','ExposureEnabled')
    slider(left,'Exposure amount','World','Exposure',-3,3,0.1)
    toggle(left,'Custom ambience','World','AmbientEnabled')
    color(left,'Ambient color','World','Ambient')
    toggle(left,'Remove shadows','World','RemoveShadows')
    toggle(left,'Custom atmosphere','World','AtmosphereEnabled')
    slider(left,'Atmosphere density','World','Density',0,1,0.01)
    slider(left,'Atmosphere haze','World','Haze',0,10,0.1)
    color(left,'Atmosphere color','World','AtmosphereColor')
    toggle(right,'Bloom','World','BloomEnabled')
    slider(right,'Bloom intensity','World','BloomIntensity',0,5,0.01)
    slider(right,'Bloom size','World','BloomSize',0,56,1)
    slider(right,'Bloom threshold','World','BloomThreshold',0,3,0.01)
    toggle(right,'Color correction','World','ColorEnabled')
    slider(right,'Brightness','World','Brightness',-1,1,0.01)
    slider(right,'Contrast','World','Contrast',-1,1,0.01)
    slider(right,'Saturation','World','Saturation',-1,1,0.01)
    color(right,'Tint','World','Tint')
    left,right=sections('Misc','Misc / Universal','Scripts')
    local function action(fn)
        local success,problem=pcall(fn)
        if not success then library:SendNotification(tostring(problem),5) end
    end
    left:AddButton({text='Copy server info',callback=function() action(function()
        assert(type(setclipboard)=='function','Executor does not support clipboard')
        setclipboard('PlaceId: '..tostring(game.PlaceId)..'\nJobId: '..tostring(game.JobId))
    end) end})
    left:AddButton({text='Rejoin server',confirm=true,callback=function() action(function()
        game:GetService('TeleportService'):TeleportToPlaceInstance(game.PlaceId,game.JobId,game:GetService('Players').LocalPlayer)
    end) end})
    right:AddButton({text='Dex Explorer',callback=function() tools:RunScript('Dex') end})
    right:AddButton({text='Remote Spy',callback=function() tools:RunScript('RemoteSpy') end})
    right:AddText({text='External tools download only when launched and have their own close controls.'})
    left:AddText({text='Auto money, lockpick, staff detection and hitsounds require game-specific work.'})
    left,right=sections('Players','Player list','Selected player')
    local search,playerMap,selectedLabel,mode='',{},nil,'Neutral'
    local playerList,details
    local function updateDetails()
        local player=tools.Selected
        if not player then details:SetText('Display name: —\nUsername: —\nPriority: —'); return end
        details:SetText('Display name: '..player.DisplayName..'\nUsername: @'..player.Name..'\nPriority: '..(engine.playerModes[player.UserId] or 'Neutral'))
    end
    local function refreshPlayers(leaving)
        local values,map=tools:PlayerList(search)
        if leaving then
            for label,player in pairs(map) do
                if player==leaving then map[label]=nil; local index=table.find(values,label); if index then table.remove(values,index) end end
            end
            if tools.Selected==leaving then tools:SetSelected(nil); tools:SetSpectating(false) end
        end
        playerMap=map
        playerList:SetValues(values)
        if not map[selectedLabel] then selectedLabel=nil end
        playerList:Select(selectedLabel,true)
        updateDetails()
    end
    left:AddBox({text='Search players',flag='Players_Search',input='',callback=function(value) search=value; refreshPlayers() end})
    playerList=left:AddList({text='Display name / Username',flag='Players_Selected',values={},callback=function(label)
        selectedLabel=label; tools:SetSelected(playerMap[label]); updateDetails()
    end})
    details=right:AddText({text='Display name: —\nUsername: —\nPriority: —'})
    right:AddList({text='Priority',flag='Players_Priority',values={'Neutral','Friend','Enemy'},selected='Neutral',callback=function(value) mode=value end})
    right:AddButton({text='Apply priority',callback=function()
        if tools.Selected then engine.playerModes[tools.Selected.UserId]=mode; engine:ResetTarget(); melee:Reset(); silent:Reset(); updateDetails() end
    end})
    right:AddButton({text='Spectate selected',callback=function()
        if tools.Selected then tools:SetSpectating(true) else library:SendNotification('Select a player first',4) end
    end})
    right:AddButton({text='Stop spectating',callback=function() tools:SetSpectating(false) end})
    right:AddText({text='Friend: excluded from aim and melee. Enemy: preferred among eligible targets. Priority is session-only.'})
    refreshPlayers()
    engine:Connect(game:GetService('Players').PlayerAdded,function() refreshPlayers() end)
    engine:Connect(game:GetService('Players').PlayerRemoving,function(player) refreshPlayers(player) end)
    left,right=sections('Profiles','Local profiles','Interface')
    local profileName='default'
    left:AddBox({text='Profile name',flag='profile_name',input=profileName,callback=function(value) profileName=value end})
    local function profilePath()
        assert(#profileName>0 and #profileName<=48 and profileName:match('^[%w _%-]+$'),'Use 1-48 letters, digits, spaces, _ or -')
        return 'Legit/Universal/configs/'..profileName..'.json'
    end
    local function notifyAction(action)
        local success,problem=pcall(action)
        library:SendNotification(success and 'Profile updated' or tostring(problem),4)
    end
    left:AddButton({text='Save profile',callback=function() notifyAction(function()
        profilePath()
        local data={version=1,settings={}}
        for _,entry in ipairs(registered) do
            local value=config[entry.Group][entry.Key]
            if entry.Kind=='color' then value={value.R,value.G,value.B,config.Alpha[flag(entry.Group,entry.Key)] or 1} end
            if entry.Kind=='bind' then value=typeof(value)=='EnumItem' and value.Name or 'none' end
            data.settings[flag(entry.Group,entry.Key)]=value
        end
        writefile(profilePath(),game:GetService('HttpService'):JSONEncode(data))
    end) end})
    local function applyEntry(entry,value)
        if entry.Kind=='toggle' then assert(type(value)=='boolean'); entry.Option:SetState(value)
        elseif entry.Kind=='slider' then assert(type(value)=='number' and value==value and math.abs(value)<math.huge); entry.Option:SetValue(value)
        elseif entry.Kind=='list' then assert(table.find(entry.Choices,value)); entry.Option:Select(value)
        elseif entry.Kind=='color' then
            assert(type(value)=='table' and (#value==3 or #value==4))
            for _,channel in ipairs(value) do assert(type(channel)=='number' and channel==channel and channel>=0 and channel<=1) end
            entry.Option:SetColor(Color3.new(value[1],value[2],value[3]))
            entry.Option:SetTrans(1-(value[4] or 1))
        elseif entry.Kind=='bind' then
            assert(type(value)=='string')
            if value=='none' then entry.Option:SetBind(Enum.KeyCode.Backspace); return end
            local enum
            local success=pcall(function() enum=Enum.KeyCode[value] end)
            if not success or not enum then pcall(function() enum=Enum.UserInputType[value] end) end
            assert(enum and enum~=Enum.KeyCode.Unknown,'Invalid aim key')
            entry.Option:SetBind(enum)
        end
    end
    left:AddButton({text='Load profile',callback=function() notifyAction(function()
        local path=profilePath()
        assert(isfile(path),'Profile does not exist')
        local data=game:GetService('HttpService'):JSONDecode(readfile(path))
        assert(data.version==1 and type(data.settings)=='table','Unsupported profile')
        -- Validate in advance against lightweight option stubs; avoid partial applies.
        for _,entry in ipairs(registered) do
            local value=data.settings[flag(entry.Group,entry.Key)]
            if value~=nil then
                local checked=table.clone(entry)
                checked.Option=setmetatable({},{__index=function() return function() end end})
                applyEntry(checked,value)
            end
        end
        for _,entry in ipairs(registered) do
            local value=data.settings[flag(entry.Group,entry.Key)]
            if value~=nil then applyEntry(entry,value) end
        end
        engine.held=false; engine.toggled=false; engine:ResetTarget()
    end) end})
    left:AddButton({text='Reset defaults',confirm=true,callback=function()
        for _,entry in ipairs(registered) do
            local value=entry.Default
            if entry.Kind=='color' then value={value.R,value.G,value.B,1} end
            if entry.Kind=='bind' then value=value.Name end
            applyEntry(entry,value)
        end
        engine.held=false; engine.toggled=false; engine:ResetTarget()
    end})
    right:AddText({text='RightShift: show / hide menu'})
    right:AddText({text='END: unload all features'})
    right:AddText({text='Opacity 0 = invisible; 1 = solid'})
    color(right,'UI accent','Interface','Accent')
    slider(right,'UI scale','Interface','Scale',70,125,5,' %')
    remember('Interface','MenuKey',right:AddBind({text='Menu key',flag='Interface_MenuKey',bind=config.Interface.MenuKey,
        keycallback=function(key)
            config.Interface.MenuKey=key
            library.Obsidian.ToggleKeybind=typeof(key)=='EnumItem' and key or Enum.KeyCode.Unknown
        end}),'bind')
    right:AddButton({text='Show aim status',callback=function() library:SendNotification(engine.Status or 'Aimbot: OFF',5) end})
    right:AddButton({text='Toggle status watermark',callback=function()
        library.showStatus=not library.showStatus
        library.StatusLabel:SetVisible(library.showStatus)
    end})
    right:AddButton({text='Unload',confirm=true,callback=function() app:Unload() end})
    left,right=sections('UI Settings','Debugging','Combat diagnostics')
    local debugEnabled=toggle(left,'Enable diagnostic logs','Debug','Enabled')
    toggle(left,'Echo logs to console','Debug','Console')
    local traceRays=toggle(left,'Trace nearby melee rays','Debug','CaptureRays')
    left:AddButton({text='Copy debug report',callback=function() action(function()
        assert(type(setclipboard)=='function','Executor does not support clipboard')
        setclipboard(logger:Report(app:DebugContext()))
        library:SendNotification('Debug report copied',4)
    end) end})
    left:AddButton({text='Save debug report',callback=function() action(function()
        local path=logger:Save(app:DebugContext())
        library:SendNotification('Saved: '..path,5)
    end) end})
    local function clearDiagnostics()
        logger:Clear(); melee.Counters={}; melee.lastSummary=0; silent.Counters={}; silent.lastSummary=0
    end
    left:AddButton({text='Clear debug log',callback=clearDiagnostics})
    right:AddButton({text='Start melee capture',callback=function()
        clearDiagnostics(); debugEnabled:SetState(true); traceRays:SetState(true)
        logger:Write('info','Melee','capture','Capture started',app:DebugContext())
        library:SendNotification('Capture started. Enable melee, close menu and try several swings, then save the report.',7)
    end})
    right:AddButton({text='Stop debug capture',callback=function()
        logger:Write('info','Melee','capture','Capture stopped',app:DebugContext())
        traceRays:SetState(false); debugEnabled:SetState(false)
    end})
    right:AddButton({text='Start silent capture',callback=function()
        clearDiagnostics(); debugEnabled:SetState(true); traceRays:SetState(true)
        logger:Write('info','Silent','capture','Capture started',app:DebugContext())
        library:SendNotification('Capture started. Enable Silent Aim, close menu, fire normally and save the report.',7)
    end})
    right:AddText({text='Keeps up to 400 entries in memory. File export is manual.'})
    right:AddText({text='Client hits do not confirm server damage.'})
    engine:Connect(game:GetService('UserInputService').InputBegan,function(input,processed)
        if not game:GetService('UserInputService'):GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.End then app:Unload() end
    end)
    engine:Start()
    melee:Start()
    silent:Start()
    tools:Start()
    library:SendNotification('Legit loaded ['..renderMode..'] | RightShift: menu | END: unload',5)
end,debug.traceback)
if not ok then app:Unload(); error('[Legit] '..tostring(message),0) end
return app
