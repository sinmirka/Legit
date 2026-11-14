-- Bounded local diagnostics. No network transport; file/clipboard export is explicit.
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
    self.environment.Build='obsidian-diagnostics-v1'
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
        total=0,throttles={},states={},started=os.clock(),environment={}},Diagnostics)
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
return Diagnostics
