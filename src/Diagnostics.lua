-- Local diagnostics. Hooks write memory only; periodic persistence runs on Heartbeat.
local Diagnostics={}
Diagnostics.__index=Diagnostics
local function clean(value,limit)
    return tostring(value):gsub('[\r\n]',' '):sub(1,limit or 300)
end
local function fields(data)
    local result={}
    for key,value in pairs(data or {}) do table.insert(result,clean(key)..'='..clean(value)) end
    table.sort(result)
    return table.concat(result,' ')
end
function Diagnostics:RefreshEnvironment()
    self.environment.PlaceId=game.PlaceId or 'unknown'
    self.environment.GameId=game.GameId or 'unknown'
    self.environment.Build='obsidian-autolog-v2'
    for _,name in ipairs({'hookfunction','hookmetamethod','getnamecallmethod','checkcaller','getcallingscript','newcclosure','writefile','setclipboard'}) do
        self.environment[name]=type(getfenv()[name])=='function'
    end
    if type(identifyexecutor)=='function' then
        local ok,name,version=pcall(identifyexecutor)
        if ok then self.environment.Executor=clean(name)..' '..clean(version or '') end
    end
end
function Diagnostics.new(settings,capacity)
    local self=setmetatable({settings=settings,capacity=capacity or 400,entries={},head=0,count=0,
        total=0,throttles={},states={},started=os.clock(),environment={SessionUnix=os.time()}},Diagnostics)
    self:RefreshEnvironment()
    return self
end
function Diagnostics:Write(level,component,event,message,data,interval)
    if not self.settings.Enabled then return false end
    local key=component..'.'..event
    local now=os.clock()
    if interval and self.throttles[key] and now-self.throttles[key]<interval then return false end
    self.throttles[key]=now
    local line=string.format('[+%.3fs] [%s] %s.%s %s',now-self.started,level,component,event,clean(message,1000))
    local extra=fields(data)
    if extra~='' then line=line..' | '..extra end
    self.head=self.head%self.capacity+1
    self.entries[self.head]=line
    self.count=math.min(self.count+1,self.capacity); self.total+=1
    self.dirty=true
    if self.settings.Console then pcall(print,'[Legit] '..line) end
    return true
end
function Diagnostics:State(component,event,value,data)
    if not self.settings.Enabled then return end
    local key=component..'.'..event
    if self.states[key]==value then return end
    if self:Write('info',component,event,value,data,0.5) then self.states[key]=value end
end
function Diagnostics:Clear()
    self.entries,self.throttles,self.states={},{},{}
    self.head,self.count,self.total=0,0,0
    self.lastJournalTotal=0; self.dirty=true
end
function Diagnostics:Report(context)
    self:RefreshEnvironment()
    local lines={'Legit diagnostic report','Environment: '..fields(self.environment),'Current: '..fields(context),
        string.format('Entries: %d / %d; overwritten: %d',self.count,self.capacity,self.total-self.count)}
    for offset=1,self.count do
        local index=(self.head-self.count+offset-1)%self.capacity+1
        table.insert(lines,self.entries[index])
    end
    return table.concat(lines,'\n')..'\n'
end
function Diagnostics:Save(context)
    for _,path in ipairs({'Legit','Legit/Universal','Legit/Universal/logs'}) do
        if type(isfolder)~='function' or not isfolder(path) then
            local ok,problem=pcall(makefolder,path)
            if not ok and not (type(isfolder)=='function' and isfolder(path)) then error(problem) end
        end
    end
    local path='Legit/Universal/logs/latest.txt'
    writefile(path,self:Report(context))
    return path
end
function Diagnostics:Context()
    if not self.context then return {} end
    local ok,value=pcall(self.context)
    return ok and value or {ContextError=tostring(value)}
end
function Diagnostics:Flush(force)
    if self.saving or (not force and not self.dirty) then return end
    if self.settings.AutoSave==false then return end
    if type(writefile)~='function' or type(makefolder)~='function' then self.AutoSaveStatus='File API unavailable'; return end
    self.saving=true
    local ok,problem=pcall(function()
        local context=self:Context()
        local report=self:Report(context)
        if #report>262144 then report=report:sub(1,4096)..'\n[Older report text truncated]\n'..report:sub(-250000) end
        local directory='Legit/Universal/logs/'
        for _,path in ipairs({'Legit','Legit/Universal','Legit/Universal/logs'}) do
            if type(isfolder)~='function' or not isfolder(path) then pcall(makefolder,path) end
        end
        if not self.rotated then
            self.rotated=true
            if type(isfile)=='function' and type(readfile)=='function' and isfile(directory..'latest.txt') then
                local previous=readfile(directory..'latest.txt')
                writefile(directory..'previous.txt',previous:sub(-262144))
            end
        end
        writefile(directory..'latest.txt',report)
        local first=math.max(self.lastJournalTotal or 0,self.total-self.count)
        local lines={}
        for serial=first+1,self.total do
            local index=(self.head-(self.total-serial)-1)%self.capacity+1
            table.insert(lines,self.entries[index])
        end
        if #lines>0 then
            local text=table.concat(lines,'\n')..'\n'
            if #(self.journalText or '')+#text>262144 then self.journalIndex=(self.journalIndex or 1)%4+1; self.journalText='' end
            self.journalText=((self.journalText or '')..text):sub(-262144)
            writefile(directory..'events-'..tostring(self.journalIndex or 1)..'.log',self.journalText)
        end
        self.lastJournalTotal=self.total; self.dirty=false
        self.AutoSaveStatus='Saved: '..directory..'latest.txt'
    end)
    self.saving=false
    if not ok then self.AutoSaveStatus='Save failed: '..tostring(problem) end
end
function Diagnostics:Start(context)
    self.context=context; self.AutoSaveStatus='Starting'
    self:Write('info','App','start','Session started',self:Context())
    self:Flush(true)
    local lastPulse,nextFlush=os.clock(),os.clock()+2
    self.heartbeat=game:GetService('RunService').Heartbeat:Connect(function(dt)
        local now=os.clock()
        local elapsed=math.max(now-lastPulse,type(dt)=='number' and dt or 0); lastPulse=now
        if elapsed>0.5 then self:Write('warn','Runtime','stall','Long frame',{Seconds=string.format('%.3f',elapsed)}) end
        if now<nextFlush then return end; nextFlush=now+2
        self:Write('info','Runtime','snapshot','State snapshot',self:Context())
        self:Flush()
    end)
    local function connectError(serviceName,signalName,callback)
        local ok,connection=pcall(function() return game:GetService(serviceName)[signalName]:Connect(callback) end)
        if ok then self[serviceName]=connection end
    end
    connectError('ScriptContext','Error',function(message,stack)
        self:Write('error','Runtime','script',tostring(message)..' '..tostring(stack))
    end)
    connectError('LogService','MessageOut',function(message,kind)
        if kind==Enum.MessageType.MessageWarning or kind==Enum.MessageType.MessageError then
            self:Write('warn','Runtime','console',message)
        end
    end)
end
function Diagnostics:Destroy()
    if self.destroyed then return end
    self.destroyed=true
    self:Write('info','App','stop','Session ended',self:Context())
    self:Flush(true)
    for _,connection in pairs({self.heartbeat,self.ScriptContext,self.LogService}) do connection:Disconnect() end
end
return Diagnostics
