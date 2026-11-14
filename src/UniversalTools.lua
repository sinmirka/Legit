local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Lighting=game:GetService('Lighting')
local Tools={}
Tools.__index=Tools
local function humanoid(player)
    local character=player and player.Character
    return character and character:FindFirstChildOfClass('Humanoid')
end
function Tools.new(config,engine,library)
    return setmetatable({config=config,engine=engine,library=library,alive=true,
        applied={},effects={},connections={},launched={}},Tools)
end
-- Restore only values we still own, preserving newer writes from the game or other scripts.
function Tools:Reconcile(desired)
    for object,properties in pairs(self.applied) do
        for key,state in pairs(properties) do
            if not desired[object] or desired[object][key]==nil then
                pcall(function() if object[key]==state.Last then object[key]=state.Original end end)
                properties[key]=nil
            end
        end
        if not next(properties) then self.applied[object]=nil end
    end
    for object,properties in pairs(desired) do
        for key,value in pairs(properties) do
            pcall(function()
                local current=object[key]
                local states=self.applied[object]
                if not states then states={}; self.applied[object]=states end
                local state=states[key]
                if not state then state={Original=current}; states[key]=state
                elseif current~=state.Last then state.Original=current end
                object[key]=value; state.Last=value
            end)
        end
    end
end
function Tools:Effect(name,class,enabled)
    local effect=self.effects[name]
    if enabled then
        if not effect or not effect.Parent then
            effect=Instance.new(class); effect.Name='Legit'..name; effect.Parent=Lighting
            self.effects[name]=effect
        end
        return effect
    elseif effect then effect:Destroy(); self.effects[name]=nil end
end
function Tools:Step()
    if not self.alive then return end
    local desired={}
    local function set(object,key,value)
        if not object then return end
        desired[object]=desired[object] or {}; desired[object][key]=value
    end
    local c,w=self.config.Character,self.config.World
    local character=Players.LocalPlayer.Character
    local hum=humanoid(Players.LocalPlayer)
    if hum and hum.Health>0 then
        if c.WalkSpeed then set(hum,'WalkSpeed',c.Speed) end
        if c.JumpOverride then
            set(hum,hum.UseJumpPower and 'JumpPower' or 'JumpHeight',hum.UseJumpPower and c.JumpPower or c.JumpHeight)
        end
        if c.Noclip and character then
            for _,part in ipairs(character:GetDescendants()) do
                if part:IsA('BasePart') then set(part,'CanCollide',false) end
            end
        end
    end
    if w.TimeEnabled then set(Lighting,'ClockTime',w.Time) end
    if w.ExposureEnabled then set(Lighting,'ExposureCompensation',w.Exposure) end
    if w.AmbientEnabled then set(Lighting,'Ambient',w.Ambient); set(Lighting,'OutdoorAmbient',w.Ambient) end
    if w.RemoveShadows then set(Lighting,'GlobalShadows',false) end
    local bloom=self:Effect('Bloom','BloomEffect',w.BloomEnabled)
    if bloom then bloom.Intensity=w.BloomIntensity; bloom.Size=w.BloomSize; bloom.Threshold=w.BloomThreshold end
    local correction=self:Effect('ColorCorrection','ColorCorrectionEffect',w.ColorEnabled)
    if correction then
        correction.Brightness=w.Brightness; correction.Contrast=w.Contrast
        correction.Saturation=w.Saturation; correction.TintColor=w.Tint
    end
    if w.AtmosphereEnabled then
        local atmosphere=Lighting:FindFirstChildOfClass('Atmosphere') or self:Effect('Atmosphere','Atmosphere',true)
        set(atmosphere,'Density',w.Density); set(atmosphere,'Haze',w.Haze); set(atmosphere,'Color',w.AtmosphereColor)
    end
    -- A selected player can respawn, leave or lose their camera subject at any time.
    local selected=self.Selected
    if self.Spectating and selected and selected.Parent==Players then
        local target=humanoid(selected)
        if target and target.Health>0 then set(workspace.CurrentCamera,'CameraSubject',target) end
    end
    self:Reconcile(desired)
    if not w.AtmosphereEnabled then self:Effect('Atmosphere','Atmosphere',false) end
end
function Tools:SetSelected(player)
    self.Selected=player
    self:Step()
end
function Tools:SetSpectating(value) self.Spectating=value; self:Step() end
function Tools:PlayerList(query)
    query=(query or ''):lower()
    local values,map={},{}
    for _,player in ipairs(Players:GetPlayers()) do
        if player~=Players.LocalPlayer and (query=='' or player.Name:lower():find(query,1,true)
            or player.DisplayName:lower():find(query,1,true)) then
            local label=player.DisplayName..' (@'..player.Name..')'
            table.insert(values,label); map[label]=player
        end
    end
    table.sort(values)
    return values,map
end
function Tools:Start()
    local function connect(signal,callback) table.insert(self.connections,signal:Connect(callback)) end
    connect(RunService.Heartbeat,function() self:Step() end)
    connect(Input.JumpRequest,function()
        local hum=humanoid(Players.LocalPlayer)
        if self.alive and self.config.Character.InfiniteJump and self.engine.focused
            and not Input:GetFocusedTextBox() and not self.library:IsInteracting()
            and not self.library:IsPointerOverUI() and hum and hum.Health>0 then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    connect(Players.PlayerRemoving,function(player)
        if self.Selected==player then self.Selected=nil; self:SetSpectating(false) end
        self.engine.playerModes[player.UserId]=nil
    end)
end
function Tools:Destroy()
    if not self.alive then return end
    self.alive=false
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self:Reconcile({})
    for name in pairs(self.effects) do self:Effect(name,'',false) end
    self.Selected,self.Spectating=nil,false
end
return Tools
