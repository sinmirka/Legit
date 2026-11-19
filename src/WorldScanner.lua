-- Incremental shared traversal: no whole-world GetDescendants or synchronous UI scan.
local RunService=game:GetService('RunService')
local Scanner={}
Scanner.__index=Scanner
function Scanner.new()
    return setmetatable({alive=true,listeners={},stack={},pending={},head=1,visited={},Budget=48,Seconds=0.002},Scanner)
end
function Scanner:Subscribe(callback)
    local entry={Connected=true,Callback=callback}
    function entry:Disconnect() self.Connected=false end
    table.insert(self.listeners,entry)
    return entry
end
function Scanner:Request() self.requested=true end
function Scanner:Emit(object)
    if not object or not object.Parent or self.visited[object] then return end
    self.visited[object]=true
    for _,entry in ipairs(self.listeners) do
        if entry.Connected then
            local ok,problem=pcall(entry.Callback,object)
            if not ok then self.LastError=tostring(problem) end
        end
    end
end
function Scanner:Step()
    if not self.alive then return end
    if self.requested then
        self.requested=false; self.visited={}
        self.stack={{Children={workspace},Index=1}}
    end
    local started=os.clock()
    self.LastProcessed=0
    for _=1,self.Budget do
        if os.clock()-started>=self.Seconds then break end
        local object
        -- Streamed objects are delivered before continuing the initial traversal.
        if self.head<=#self.pending then
            object=self.pending[self.head]; self.head+=1
        else
            self.pending={}; self.head=1
            local frame=self.stack[#self.stack]
            if not frame then break end
            object=frame.Children[frame.Index]; frame.Index+=1
            if not object then table.remove(self.stack) end
        end
        if object and (object==workspace or object.Parent) and not self.visited[object] then
            local ignored=object~=workspace and object.Name:sub(1,5)=='Legit'
            if not ignored then
                if object~=workspace then self:Emit(object) else self.visited[object]=true end
                local children=object:GetChildren()
                if #children>0 then table.insert(self.stack,{Children=children,Index=1}) end
            end
        end
        self.LastProcessed+=1
    end
    self.Scanning=self.requested or #self.stack>0 or self.head<=#self.pending
end
function Scanner:Start()
    if workspace.DescendantAdded then self.added=workspace.DescendantAdded:Connect(function(object)
        if #self.pending-self.head<4096 then table.insert(self.pending,object) else self:Request() end
    end) end
    self.heartbeat=RunService.Heartbeat:Connect(function()
        local ok,problem=pcall(self.Step,self)
        if not ok then self.LastError=tostring(problem) end
    end)
end
function Scanner:Destroy()
    self.alive=false
    if self.added then self.added:Disconnect() end
    if self.heartbeat then self.heartbeat:Disconnect() end
    self.stack={}; self.pending={}; self.visited={}; self.listeners={}
end
return Scanner
