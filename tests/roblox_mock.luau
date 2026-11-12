-- Headless API doubles. These verify code paths, not Roblox rendering fidelity.
local nativeTypeof=typeof
function typeof(value) return type(value)=='table' and value.__type or nativeTypeof(value) end
local function signal()
    local self={handlers={}}
    function self:Connect(callback)
        local connection={Connected=true}
        function connection:Disconnect() self.Connected=false end
        table.insert(self.handlers,{connection,callback})
        return connection
    end
    function self:Fire(...)
        local snapshot=table.clone(self.handlers)
        for _,entry in ipairs(snapshot) do if entry[1].Connected then entry[2](...) end end
    end
    return self
end
task={pending={}}
function task.spawn(callback,...)
    local thread=type(callback)=='thread' and callback or coroutine.create(callback)
    local ok,message=coroutine.resume(thread,...)
    assert(ok,message)
    if coroutine.status(thread)=='suspended' then table.insert(task.pending,thread) end
    return thread
end
function task.wait() return coroutine.yield() end
function tick() return os.clock() end
function warn(...) print('WARN',...) end
local global={}
function getgenv() return global end
local vector={}
vector.__index=function(v,key)
    if key=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+(v.Z or 0)^2) end
    if key=='Unit' then return v/v.Magnitude end
    if key=='Lerp' then return function(a,b,t) return a+(b-a)*t end end
end
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z,__type=z and 'Vector3' or 'Vector2'},vector) end
vector.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z and a.Z+b.Z) end
vector.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z and a.Z-b.Z) end
vector.__mul=function(a,b)
    if type(a)=='number' then a,b=b,a end
    if type(b)=='number' then return vec(a.X*b,a.Y*b,a.Z and a.Z*b) end
    return vec(a.X*b.X,a.Y*b.Y,a.Z and a.Z*b.Z)
end
vector.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z and a.Z/b) end
Vector2={new=function(x,y) return vec(x,y) end}; Vector2.zero=vec(0,0)
Vector3={new=function(x,y,z) return vec(x,y,z) end}; Vector3.zero=vec(0,0,0)
local udim={}
udim.__index=udim
function udim:Lerp(b,t) return self+(b-self)*t end
local function dim(xs,xo,ys,yo) return setmetatable({X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo},__type='UDim2'},udim) end
udim.__add=function(a,b) return dim(a.X.Scale+b.X.Scale,a.X.Offset+b.X.Offset,a.Y.Scale+b.Y.Scale,a.Y.Offset+b.Y.Offset) end
udim.__sub=function(a,b) return dim(a.X.Scale-b.X.Scale,a.X.Offset-b.X.Offset,a.Y.Scale-b.Y.Scale,a.Y.Offset-b.Y.Offset) end
udim.__mul=function(a,b) return dim(a.X.Scale*b,a.X.Offset*b,a.Y.Scale*b,a.Y.Offset*b) end
UDim2={new=dim,fromOffset=function(x,y) return dim(0,x,0,y) end}
UDim={new=function(scale,offset) return {Scale=scale,Offset=offset} end}
local color={}; color.__index=color
local function rgb(r,g,b) return setmetatable({R=r,G=g,B=b,r=r,g=g,b=b,__type='Color3'},color) end
function color:Lerp(b,t) return rgb(self.R+(b.R-self.R)*t,self.G+(b.G-self.G)*t,self.B+(b.B-self.B)*t) end
function color:ToHSV() return 0.5,0.5,0.5 end
Color3={new=rgb,fromRGB=function(r,g,b) return rgb(r/255,g/255,b/255) end,fromHSV=function(h,s,v) return rgb(h,s,v) end}
Enum=setmetatable({},{__index=function(self,category)
    local group=setmetatable({GetEnumItems=function() return {} end},{__index=function(t,name)
        local value={Name=name,Value=name=='Camera' and 200 or name=='Last' and 2000 or 0,__type='EnumItem'}
        rawset(t,name,value); return value
    end})
    rawset(self,category,group); return group
end})
local object={}; object.__index=object
function object:Destroy() self.Destroyed=true; self.Parent=nil end
function object:IsA(class) return self.ClassName==class or class=='Instance' or (class=='BasePart' and self.ClassName=='Part') end
function object:FindFirstChild(name) return self.Children[name] end
function object:FindFirstChildOfClass(class)
    for _,child in pairs(self.Children) do if child.ClassName==class then return child end end
end
function object:IsDescendantOf(parent) return parent==workspace or parent==self.Parent end
Instance={new=function(class) return setmetatable({ClassName=class,Children={},Destroying=signal(),Activated=signal(),FocusLost=signal(),
    InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),AbsolutePosition=vec(200,100),AbsoluteSize=vec(690,620),__type='Instance'},object) end}
RaycastParams={new=function() return {} end}
local drawMeta={}
DRAWINGS={}
drawMeta.__index=function(self,key)
    if key=='TextBounds' then
        local size=type(self.Size)=='number' and self.Size or 13
        return vec(#tostring(self.Text or '')*size*0.5,size)
    end
end
Drawing={new=function(class)
    local object=setmetatable({Class=class,Position=vec(0,0),Size=class=='Text' and 13 or vec(100,20),Text='',Visible=true,Transparency=1,ZIndex=0},drawMeta)
    function object:Remove() assert(not self.Removed,'Drawing removed twice'); self.Removed=true; self.Visible=false end
    table.insert(DRAWINGS,object)
    return object
end}
local services={}
local player={UserId=1,Name='Local',Neutral=false,Team={},Children={}}
player.PlayerGui=Instance.new('PlayerGui')
function player:WaitForChild(name) return assert(self[name],name) end
function player:IsFriendsWith() return false end
local players={LocalPlayer=player,PlayerAdded=signal(),PlayerRemoving=signal(),list={player}}
player.Parent=players
function players:GetPlayers() return self.list end
services.Players=players
services.TextService={GetTextSize=function(_,value,size)
    local maxWidth,lines=0,0
    for line in (value..'\n'):gmatch('(.-)\n') do maxWidth=math.max(maxWidth,#line*size*0.5); lines+=1 end
    return vec(maxWidth,size*math.max(1,lines))
end}
services.RunService={RenderStepped=signal(),bindings={},priorities={}}
function services.RunService:BindToRenderStep(name,priority,callback) self.bindings[name]=callback; self.priorities[name]=priority end
function services.RunService:UnbindFromRenderStep(name) self.bindings[name]=nil end
services.UserInputService={InputBegan=signal(),InputEnded=signal(),InputChanged=signal(),WindowFocusReleased=signal(),WindowFocused=signal()}
function services.UserInputService:GetFocusedTextBox() return nil end
function services.UserInputService:GetMouseLocation() return vec(10,10) end
services.UserInputService.Down={}
function services.UserInputService:IsKeyDown(key) return self.Down[key]==true end
function services.UserInputService:IsMouseButtonPressed(key) return self.Down[key]==true end
services.ContextActionService={BindAction=function() end,UnbindAction=function() end}
services.CoreGui={}
services.Stats={Network={ServerStatsItem={['Data Ping']={GetValue=function() return 20 end}}}}
services.TweenService={GetValue=function(_,alpha) return math.clamp(alpha,0,1) end}
local json={}
services.HttpService={GenerateGUID=function() return tostring(os.clock()) end,
    JSONEncode=function(_,value) local key='JSON'..tostring(#json+1); json[#json+1]=value; return key end,
    JSONDecode=function(_,text) local id=tonumber(text:match('JSON(%d+)')); return json[id] end}
workspace={CurrentCamera={ViewportSize=vec(1280,900),CFrame={Position=vec(0,0,0),LookVector=vec(0,0,1)},CameraType=Enum.CameraType.Custom}}
local frame={}; frame.__index=frame
function frame:Lerp(other,alpha) other.LastAlpha=alpha; return other end
function frame:PointToWorldSpace(position) return self.Position+position end
CFrame={lookAt=function(position,target) return setmetatable({Position=position,LookVector=(target-position).Unit},frame) end}
workspace.CurrentCamera.CFrame=setmetatable(workspace.CurrentCamera.CFrame,frame)
function workspace.CurrentCamera:WorldToViewportPoint(position) return vec(640+position.X,450-position.Y,position.Z),true end
function workspace:Raycast() return self.Hit end
game={Loaded=signal()}
function game:IsLoaded() return true end
function game:GetService(name) assert(services[name],name); return services[name] end
function game:HttpGet(url)
    local path=url:match('sinmirka/Legit/[^/]+/(.+)') or url:match('sinmirka/Legit@[^/]+/(.+)')
    assert(path,'Unexpected external download: '..url)
    if path:match('^assets/') then return '\137PNG\r\n\26\nPNG' end
    assert(SOURCES[path],'Missing remote module '..path)
    return SOURCES[path]
end
local files={}
function makefolder() end
function isfile(path) return files[path]~=nil end
function readfile(path) assert(files[path],path); return files[path] end
function writefile(path,data) files[path]=data end
MOCK={services=services,players=players,files=files,vec=vec,object=object}
