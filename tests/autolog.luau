local Diagnostics=assert(loadstring(SOURCES['src/Diagnostics.lua']))()
local logSignal=Instance.new('BindableEvent').Activated
local errorSignal=Instance.new('BindableEvent').Activated
MOCK.services.LogService={MessageOut=logSignal}; MOCK.services.ScriptContext={Error=errorSignal}
local latest='Legit/Universal/logs/latest.txt'
MOCK.files[latest]='previous-session-evidence'
local writes=0; local nativeWrite=writefile
writefile=function(...) writes+=1; return nativeWrite(...) end
local settings={Enabled=true,Console=false,CaptureRays=true,AutoSave=true}
local log=Diagnostics.new(settings,20)
log:Start(function() return {Phase='test'} end)
assert(MOCK.files[latest]:find('Session started',1,true),'startup autosaves without buttons')
assert(MOCK.files['Legit/Universal/logs/previous.txt']=='previous-session-evidence','previous session survives reload')
local before=writes
for index=1,30 do log:Write('info','Shot','seen','shot-'..index) end
assert(writes==before,'hot event recording performs zero file IO')
log:Flush()
assert(MOCK.files[latest]:find('shot-30',1,true) and not MOCK.files[latest]:find('shot-1\n',1,true),'bounded newest report')
assert(MOCK.files['Legit/Universal/logs/events-1.log']:find('shot-30',1,true),'rolling history saved')
logSignal:Fire('game warning',Enum.MessageType.MessageWarning)
errorSignal:Fire('script failure','stack trace')
MOCK.services.RunService.Heartbeat:Fire(15)
local report=log:Report()
assert(report:find('game warning',1,true) and report:find('script failure',1,true) and report:find('Runtime.stall',1,true),'warnings, errors and stalls recorded')
local write=writefile; writefile=function() error('disk unavailable') end
assert(pcall(log.Flush,log,true) and log.AutoSaveStatus:find('disk unavailable',1,true),'file failures isolated from gameplay')
writefile=write; log:Flush(true); assert(log.AutoSaveStatus:find('Saved:',1,true),'autosave recovers')
settings.AutoSave=false; before=writes; log:Write('info','Test','disabled','memory only'); log:Flush(); assert(writes==before,'autosave preference respected')
settings.AutoSave=true; log:Destroy(); assert(MOCK.files[latest]:find('Session ended',1,true) and not log.heartbeat.Connected,'unload flush and disconnect')
writefile=nativeWrite
local app=assert(loadstring(SOURCES['main.lua']))()
assert(app.Config.Debug.Enabled and app.Config.Debug.CaptureRays and app.Config.Debug.AutoSave,'logging and autosave enabled by default')
assert(app.Logger.capacity==1200 and MOCK.files[latest]:find('Initial configuration',1,true),'initial settings and larger ring saved')
app:Unload()
print('PASS default autolog: no hot-path IO, startup/history preservation, warnings/errors/stalls, file failure recovery and unload')
