-- Read client-replicated dealer values using the shared incremental scanner.
local RunService=game:GetService('RunService')
local Stock={}
Stock.__index=Stock
local function dealerOf(object)
    local found
    for _=1,20 do
        object=object.Parent
        if not object or object==workspace then return found end
        local name=object.Name:lower()
        if name=='characters' then return end
        if name:find('dealer',1,true) or name:find('stock',1,true) or name:find('armory',1,true)
            or name=='legalstore' or name=='illegalstore' then found=object end
    end
    return found
end
function Stock.new(config,scanner,library)
    return setmetatable({config=config,scanner=scanner,library=library,alive=true,entries={},seen={},previous={},
        Status='Disabled',Text='No stock values found',cursor=1,rows={},changes={}},Stock)
end
function Stock:Matches(name)
    local filter=self.config.Items:lower()
    if filter=='' or filter=='all' then return true end
    for item in filter:gmatch('[^,]+') do
        item=item:match('^%s*(.-)%s*$')
        if item~='' and name:lower():find(item,1,true) then return true end
    end
    return false
end
function Stock:Add(object)
    if not self.config.Enabled or self.seen[object] or #self.entries>=1024 then return end
    if not (object:IsA('IntValue') or object:IsA('NumberValue') or object:IsA('StringValue') or object:IsA('BoolValue')) then return end
    local dealer=dealerOf(object)
    if dealer then self.seen[object]=true; table.insert(self.entries,{Object=object,Dealer=dealer}) end
end
function Stock:Step()
    if not self.alive then return end
    if not self.config.Enabled then
        self.enabled=false; self.entries={}; self.seen={}; self.previous={}; self.baseline=false
        self.cursor=1; self.rows={}; self.changes={}; self.Text='No stock values found'; self.Status='Disabled'; return
    end
    if not self.enabled then self.enabled=true; self.scanner:Request(); self.Status='Scanning dealer stock' end
    local filter=self.config.Items
    if filter~=self.filter then self.filter=filter; self.cursor=1; self.rows={}; self.changes={}; self.baseline=false end
    for _=1,32 do
        local entry=self.entries[self.cursor]
        if not entry then break end
        local object,dealer=entry.Object,entry.Dealer
        if object.Parent and dealer.Parent and object:IsDescendantOf(dealer) then
            if self:Matches(object.Name) then
                local value=tostring(object.Value)
                table.insert(self.rows,dealer.Name..' / '..object.Name..': '..value)
                if self.baseline and self.previous[object]~=value then table.insert(self.changes,object.Name..': '..value) end
                self.previous[object]=value
            end
        else
            self.seen[object]=nil; self.previous[object]=nil
            table.remove(self.entries,self.cursor); self.cursor-=1
        end
        self.cursor+=1
    end
    if self.cursor>#self.entries then
        table.sort(self.rows)
        local count=#self.rows
        self.Text=count>0 and table.concat(self.rows,'\n',1,math.min(count,128)) or 'No stock values found for this filter'
        self.Status=string.format('%d stock values%s',count,self.scanner.Scanning and ' (scanning)' or '')
        if self.baseline and self.config.Notify and #self.changes>0 then
            self.library:SendNotification('Dealer stock changed: '..table.concat(self.changes,', ',1,math.min(#self.changes,8)),6)
        end
        if not self.scanner.Scanning then self.baseline=true end
        self.cursor=1; self.rows={}; self.changes={}
    end
end
function Stock:Start()
    self.subscription=self.scanner:Subscribe(function(object) self:Add(object) end)
    local nextStep=0
    self.heartbeat=RunService.Heartbeat:Connect(function()
        if os.clock()<nextStep then return end; nextStep=os.clock()+0.1
        local ok,problem=pcall(self.Step,self)
        if not ok then self.Status='Stock error: '..tostring(problem) end
    end)
end
function Stock:Destroy()
    self.alive=false
    if self.subscription then self.subscription:Disconnect() end
    if self.heartbeat then self.heartbeat:Disconnect() end
    self.entries={}; self.seen={}; self.previous={}; self.rows={}; self.changes={}
end
return Stock
