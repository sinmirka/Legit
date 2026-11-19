-- Cached world-object ESP. Folder hints follow public Criminality examples;
-- crate variants additionally use explicit names/attributes or the crate's colour.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Objects={}
Objects.__index=Objects
local colors={Scrap=Color3.fromRGB(190,195,205),GreenCrates=Color3.fromRGB(60,235,100),
    RedCrates=Color3.fromRGB(255,65,65),Airdrops=Color3.fromRGB(255,220,50),Dealers=Color3.fromRGB(170,120,255)}
local labels={Scrap='Scrap',GreenCrates='Green crate',RedCrates='Red crate',Airdrops='Airdrop',Dealers='Dealer'}
Objects.Rarities={'Common','Uncommon','Rare','Epic','Legendary','Mythic'}
function Objects.Rarity(object,part,valueObject)
    local function parse(value)
        for rank,name in ipairs(Objects.Rarities) do
            if (type(value)=='string' and value:lower()==name:lower()) or tonumber(value)==rank then return name,rank end
        end
    end
    if valueObject and valueObject.Parent then
        local name,rank=parse(valueObject.Value)
        if name then return name,rank end
    end
    for _,container in ipairs(part and {object,part} or {object}) do
        for _,key in ipairs({'Rarity','Tier','Quality'}) do
            local value=container:GetAttribute(key)
            local child=container:FindFirstChild(key)
            if value==nil and child and (child:IsA('StringValue') or child:IsA('IntValue') or child:IsA('NumberValue')) then value=child.Value end
            local name,rank=parse(value)
            if name then return name,rank end
        end
    end
    return 'Unknown',0
end
local function normal(value) return tostring(value or ''):lower():gsub('[%s_%-]','') end
local function drawable(object) return object:IsA('Model') or object:IsA('BasePart') end
function Objects.Part(object)
    if object:IsA('BasePart') then return object end
    return object.PrimaryPart or object:FindFirstChildWhichIsA('BasePart')
end
function Objects.CrateKind(object,sample)
    local name=normal(object.Name)..normal(object:GetAttribute('CrateType'))..normal(object:GetAttribute('Type'))
    if name:find('airdrop',1,true) or name:find('supplydrop',1,true) or name:find('yellow',1,true) then return 'Airdrops' end
    if name:find('red',1,true) then return 'RedCrates' end
    if name:find('green',1,true) then return 'GreenCrates' end
    local function byColor(part)
        local c=part.Color
        if not c then return end
        if c.R>0.55 and c.G>0.45 and c.G>=c.R*0.8 and c.B<math.min(c.R,c.G)*0.65 then return 'Airdrops' end
        if c.R>c.G*1.5 and c.R>c.B*1.5 and c.R>0.25 then return 'RedCrates' end
        if c.G>c.R*1.3 and c.G>c.B*1.3 and c.G>0.2 then return 'GreenCrates' end
    end
    local part=Objects.Part(object)
    local kind=part and byColor(part)
    if kind then return kind end
    if sample and sample:IsA('BasePart') then return byColor(sample) end
end
function Objects.Classify(object)
    local root,kind
    local cursor=object
    for _=1,32 do
        if not cursor or cursor==workspace then break end
        local name=normal(cursor.Name)
        if name:sub(1,5)=='legit' or name=='characters' or cursor:IsA('Tool') then return end
        local parent=cursor.Parent
        local parentName=parent and normal(parent.Name) or ''
        if drawable(cursor) then
            if parentName=='spawnedpiles' or name:find('scrap',1,true) then root,kind=cursor,'Scrap'
            elseif name:find('dealer',1,true) or name=='armory' or name=='legalstore' or name=='illegalstore'
                or parentName=='dealers' or parentName=='bredmakurz' then root,kind=cursor,'Dealers'
            elseif name:find('crate',1,true) or name:find('airdrop',1,true) or name:find('supplydrop',1,true)
                or parentName=='spawnedcrates' or parentName=='crates' or parentName=='airdrops' then
                local crateKind=Objects.CrateKind(cursor,object)
                if crateKind then root,kind=cursor,crateKind end
            end
        end
        cursor=parent
    end
    return root,kind
end
function Objects.new(config,engine)
    local folder=Instance.new('Folder'); folder.Name='LegitObjectESP'; folder.Parent=engine.folder
    return setmetatable({config=config,engine=engine,folder=folder,alive=true,candidates={},records={},queue={},
        Status='Disabled',Counts={},connections={},candidateCount=0,scanner=engine.Scanner},Objects)
end
function Objects:Enabled()
    for kind in pairs(colors) do if self.config[kind] then return true end end
    return false
end
function Objects:Add(object)
    local root,kind=Objects.Classify(object)
    if not root then return end
    local sample=object:IsA('BasePart') and object or nil
    if self.candidates[root] then
        if not self.candidates[root].Part then self.candidates[root].Part=sample end
        if kind=='Scrap' and (object.Name=='Rarity' or object.Name=='Tier' or object.Name=='Quality')
            and (object:IsA('StringValue') or object:IsA('IntValue') or object:IsA('NumberValue')) then self.candidates[root].RarityValue=object end
        return
    end
    if self.candidateCount<2048 then
        self.candidates[root]={Kind=kind,Part=Objects.Part(root) or sample}
        self.candidateCount+=1
    end
end
function Objects:Remove(object)
    local record=self.records[object]
    if record then record.Highlight:Destroy(); record.Label:Remove(); self.records[object]=nil end
end
function Objects:Clear()
    for object in pairs(self.records) do self:Remove(object) end
    self.candidates={}; self.candidateCount=0; self.scanned=false; self.Counts={}
end
function Objects:Rescan() self:Clear(); self:Step() end
function Objects:Step()
    if not self.alive then return end
    if not self:Enabled() then self:Clear(); self.Status='Disabled'; return end
    if not self.scanned then
        self.scanned=true
        self.scanner:Request()
    end
    local camera=workspace.CurrentCamera
    local character=Players.LocalPlayer.Character
    local root=character and character:FindFirstChild('HumanoidRootPart')
    local eligible={}; self.Counts={}
    for object,data in pairs(self.candidates) do
        if not object.Parent or not object:IsDescendantOf(workspace) then self:Remove(object); self.candidates[object]=nil; self.candidateCount-=1
        else
            self.Counts[data.Kind]=(self.Counts[data.Kind] or 0)+1
            if not data.Part or not data.Part.Parent then data.Part=Objects.Part(object) end
            local distance=root and data.Part and (root.Position-data.Part.Position).Magnitude
            local rarityAllowed=true
            if data.Kind=='Scrap' then
                local name,rank=Objects.Rarity(object,data.Part,data.RarityValue); data.Rarity=name
                local minimum=table.find(Objects.Rarities,self.config.ScrapRarity) or 0
                rarityAllowed=minimum==0 or rank>=minimum
            end
            if camera and distance and distance<=self.config.MaxDistance and self.config[data.Kind] and rarityAllowed then
                table.insert(eligible,{Object=object,Data=data,Distance=distance})
            end
        end
    end
    table.sort(eligible,function(a,b) return a.Distance<b.Distance end)
    local shown={}
    local created=0
    for index,item in ipairs(eligible) do
        if index>self.config.MaxObjects then break end
        local object,data=item.Object,item.Data
        local record=self.records[object]
        if not record and created<8 then
            created+=1
            local highlight=Instance.new('Highlight'); highlight.Parent=self.folder; highlight.Adornee=object
            local label=self.engine.Drawing.new('Text'); label.Center=true; label.Outline=true; label.Size=13; label.ZIndex=20
            record={Highlight=highlight,Label=label}; self.records[object]=record
        end
        if record then
        shown[object]=true
        local color=colors[data.Kind]
        record.Highlight.FillColor=color; record.Highlight.OutlineColor=color
        record.Highlight.FillTransparency=self.config.FillTransparency; record.Highlight.OutlineTransparency=0
        record.Highlight.DepthMode=self.config.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        record.Highlight.Enabled=self.config.Highlight
        local screen,onScreen=camera:WorldToViewportPoint(data.Part.Position)
        local visible=self.config.ThroughWalls or self.engine:Visible(object,data.Part.Position,camera)
        record.Label.Visible=self.config.Labels and onScreen and screen.Z>0 and visible
        record.Label.Position=Vector2.new(screen.X,screen.Y); record.Label.Color=color
        record.Label.Text=labels[data.Kind]..(data.Kind=='Scrap' and (' ['..data.Rarity..']') or '')
            ..(self.config.Distance and string.format(' [%d studs]',item.Distance) or '')
        end
    end
    for object in pairs(self.records) do if not shown[object] then self:Remove(object) end end
    self.Status=string.format('%d visible / %d eligible',math.min(#eligible,self.config.MaxObjects),#eligible)
end
function Objects:Start()
    table.insert(self.connections,self.scanner:Subscribe(function(object)
        if self.alive and self:Enabled() then self:Add(object) end
    end))
    local nextStep=0
    table.insert(self.connections,RunService.Heartbeat:Connect(function()
        if os.clock()<nextStep then return end; nextStep=os.clock()+0.1
        local ok,problem=pcall(self.Step,self)
        if not ok and self.engine.Logger then self.engine.Logger:Write('error','Objects','update',tostring(problem),nil,2) end
    end))
end
function Objects:Destroy()
    if not self.alive then return end
    self.alive=false; for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self:Clear(); self.folder:Destroy()
end
return Objects
