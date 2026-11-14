local Diagnostics=assert(loadstring(SOURCES['src/Diagnostics.lua']))()
local settings={Enabled=false,Console=false,CaptureRays=false}
local log=Diagnostics.new(settings,3)
assert(not log:Write('info','Test','disabled','ignored') and log.count==0,'disabled logging is inert')
settings.Enabled=true
for index=1,5 do log:Write('info','Test','ring','entry-'..index) end
local report=log:Report({Phase='test'})
assert(not report:find('entry-1',1,true) and report:find('entry-3',1,true)<report:find('entry-5',1,true),'ring retains newest entries in order')
assert(report:find('overwritten: 2',1,true),'report dropped entry count')
log:Clear(); log:Write('info','Test','throttle','first',nil,10)
assert(not log:Write('info','Test','throttle','second',nil,10),'rate limiting')
log:State('Test','state','same'); log:State('Test','state','same')
assert(log.count==2,'state deduplication')
log:Clear(); assert(log.count==0 and log.total==0 and next(log.states)==nil,'clear releases entries and state')
log:Write('info','Test','clean','line1\nline2',{Field='a\rb'})
assert(log:Report():find('line1 line2',1,true),'multiline values remain one log line')
local app=assert(loadstring(SOURCES['main.lua']))()
local function button(label)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,option in ipairs(section.options) do if option.class=='button' and option.text==label then return option end end
    end end
    error('Missing button '..label)
end
button('Start melee capture').callback()
assert(app.Config.Debug.Enabled and app.Config.Debug.CaptureRays,'capture enables diagnostics only')
assert(not app.Config.Melee.Enabled,'capture does not enable attacks')
local aura=app.MeleeAura
app.Config.Melee.Enabled=true
aura:Step(1)
assert(aura.Status:find('hookmetamethod',1,true) and aura.Status:find('getnamecallmethod',1,true),'missing APIs named even while menu is open')
assert(app.Logger:Report():find('Melee.capabilities',1,true),'missing APIs recorded')
app.Library:SetOpen(false)
local players=MOCK.players
local function character(x)
    local char=Instance.new('Model'); char.Parent=workspace
    local hum=Instance.new('Humanoid'); hum.Health=100; char.Children.Humanoid=hum
    for _,name in ipairs({'Head','HumanoidRootPart'}) do
        local part=Instance.new('Part'); part.Position=MOCK.vec(x,0,0); part.Parent=char; part.Name=name
        char.Children[name]=part
    end
    return char
end
players.LocalPlayer.Character=character(0)
local target={UserId=2,Name='Target',DisplayName='Target',Parent=players,Neutral=true,Character=character(5)}
players.list={players.LocalPlayer,target}
local tool=Instance.new('Tool'); tool.Parent=players.LocalPlayer.Character; tool.Name='Fists'; tool.Enabled=true
players.LocalPlayer.Character.Children.Tool=tool
assert(app:DebugContext().EquippedTool=='Fists','report sees actual equipment before a successful preflight')
function tool:Activate() self.Activated:Fire() end
local caller=Instance.new('LocalScript'); caller.Name='BladeScript'; caller.Parent=tool
local intercepted,calls,failPrevious=nil,0,false
hookmetamethod=function(_,_,fn)
    intercepted=fn
    return function()
        calls+=1
        if failPrevious then error('original game failure') end
        return {Instance=target.Character.Children.Head},nil,'tail'
    end
end
checkcaller=function() return false end
getnamecallmethod=function() return 'Raycast' end
getcallingscript=function() return caller end
aura:Step(2)
assert(aura.target and aura.Counters['activation.attempted']==1 and aura.Counters['swing.Activated']==1,'capture distinguishes activation attempt from event')
local hit,middle,tail=intercepted(workspace,MOCK.vec(0,0,0),MOCK.vec(1,0,0))
assert(hit.Instance==target.Character.Children.Head and middle==nil and tail=='tail','diagnostic result observation preserves returns')
assert(aura.Counters['ray.seen']==1 and aura.Counters['ray.redirected']==1,'seen and redirected counters')
assert(app.Logger:Report():find('Melee.ray.result',1,true),'real client result recorded')
getcallingscript=function() error('caller introspection failed') end
local before=calls
assert(pcall(intercepted,workspace,MOCK.vec(0,0,0),MOCK.vec(1,0,0)) and calls==before+1,'caller errors fail through to original game method')
assert(aura.Counters['hook.error']==1 and app.Logger:Report():find('caller introspection failed',1,true),'hook errors observable')
getcallingscript=function() return caller end
failPrevious=true
local ok,problem=pcall(intercepted,workspace,MOCK.vec(0,0,0),MOCK.vec(1,0,0))
assert(not ok and tostring(problem):find('original game failure',1,true),'game errors retain their semantics')
failPrevious=false
caller.Parent=nil; caller.Name='UnknownHitbox'
intercepted(workspace,MOCK.vec(0,0,0),MOCK.vec(1,0,0))
assert(aura.Counters['ray.skip.caller mismatch']==1,'caller filtering is observable without relaxing scope')
app.Library:SetOpen(true); aura:Step(3)
assert(aura.Status=='Paused: menu open','pause reason explicit')
local made={}
makefolder=function(path) table.insert(made,path) end
button('Save debug report').callback()
local saved=assert(MOCK.files['Legit/Universal/logs/latest.txt'])
assert(#made==3 and made[3]=='Legit/Universal/logs','create executor log folders')
assert(saved:find('hookmetamethod=true',1,true) and saved:find('MeleeStatus=Paused: menu open',1,true),'export current capabilities and context')
local copied
setclipboard=function(text) copied=text end
button('Copy debug report').callback(); assert(copied:find('Legit diagnostic report',1,true),'clipboard export')
button('Stop debug capture').callback()
assert(not app.Config.Debug.Enabled and not app.Config.Debug.CaptureRays,'stop capture keeps report')
assert(app.Logger.count>0,'stop retains prior entries')
button('Clear debug log').callback()
assert(app.Logger.count==0 and next(aura.Counters)==nil,'clear resets both ring and counters')
app:Unload()
print('PASS bounded diagnostics: rate limits, exports, live capabilities, melee counters, hook error isolation and unchanged game returns/errors')
