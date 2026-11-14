local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Lighting=game:GetService('Lighting')
local Tools={}
Tools.__index=Tools
Tools.Scripts={
    Dex={URL='https://github.com/FusionWTF/Dex-Explorer/releases/download/Beta/out.lua',
        Source='https://github.com/FusionWTF/DeX-Explorer'},
    RemoteSpy={URL='https://raw.githubusercontent.com/78n/SimpleSpy/de04922e7b26d932111a04a18ee8d3341523ee5c/SimpleSpySource.lua',
        Source='https://github.com/78n/SimpleSpy'},
}
local function humanoid(player)
    local character=player and player.Character
    return character and character:FindFirstChildOfClass('Humanoid')
end
function Tools.new(config,engine,library)
    return setmetatable({config=config,engine=engine,library=library,alive=true,
        applied={},effects={},connections={},launched={},staminaTables={},StaminaStatus='Disabled',
        prompts=setmetatable({},{__mode='k'})},Tools)
end
function Tools:TrackPrompt(object)
    if self.alive and self.config.Interaction.Instant and object:IsA('ProximityPrompt') then self.prompts[object]=true end
end
function Tools:InteractionStep(set)
    if not self.config.Interaction.Instant then
        self.prompts=setmetatable({},{__mode='k'}); self.promptActive=false; return
    end
    if not self.promptActive then
        self.promptActive=true
        for _,object in ipairs(workspace:GetDescendants()) do self:TrackPrompt(object) end
    end
    for prompt in pairs(self.prompts) do
        if prompt.Parent and prompt:IsDescendantOf(workspace) then set(prompt,'HoldDuration',0)
        else self.prompts[prompt]=nil end
    end
end
function Tools:StaminaStatusTo(status)
    self.StaminaStatus=status
    if self.engine.Logger then self.engine.Logger:State('Stamina','status',status) end
end
function Tools:RescanStamina()
    self.staminaTables={}; self.nextStaminaScan=0
end
function Tools:StaminaStep(character,hum)
    if not self.config.Character.InfiniteStamina then
        self:RescanStamina(); self.staminaCharacter=nil; self:StaminaStatusTo('Disabled'); return
    end
    if type(getgc)~='function' then self:StaminaStatusTo('Unavailable: missing getgc'); return end
    if not character or not hum or hum.Health<=0 then
        self:RescanStamina(); self:StaminaStatusTo('Waiting for character'); return
    end
    if self.staminaCharacter~=character then self:RescanStamina(); self.staminaCharacter=character end
    local now=os.clock()
    if now>=(self.nextStaminaScan or 0) then
        self.nextStaminaScan=now+15
        local ok,objects=pcall(getgc,true)
        if not ok or type(objects)~='table' then
            self:StaminaStatusTo('Unavailable: getgc scan failed'); self.nextStaminaScan=now+5; return
        end
        local found={}
        for _,object in ipairs(objects) do
            if type(object)=='table' and not table.isfrozen(object) then
                local value=rawget(object,'S')
                if type(value)=='number' and value==value and value>=0 and value<=100 then
                    table.insert(found,object)
                    if #found>=128 then break end
                end
            end
        end
        self.staminaTables=found
        if #found==0 then self.nextStaminaScan=now+5 end
    end
    local count=0
    for index=#self.staminaTables,1,-1 do
        local object=self.staminaTables[index]
        local value=rawget(object,'S')
        if not table.isfrozen(object) and type(value)=='number' and value==value and value>=0 and value<=100 then
            local written=pcall(rawset,object,'S',100)
            if written then count+=1 else table.remove(self.staminaTables,index) end
        else table.remove(self.staminaTables,index) end
    end
    self:StaminaStatusTo(count>0 and ('Refilling '..count..' candidate stamina table(s)') or 'No compatible stamina table found')
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
function Tools:SpeedStep(character,hum)
    local c=self.config.Character
    if not c.VelocitySpeed then self.SpeedStatus='Disabled'; return end
    local root=character and character:FindFirstChild('HumanoidRootPart')
    if not hum or hum.Health<=0 or not root then self.SpeedStatus='Waiting for character'; return end
    if root.Anchored or hum.Sit or hum.PlatformStand or hum.SeatPart then self.SpeedStatus='Paused: anchored / seated / ragdoll'; return end
    local move,velocity=hum.MoveDirection,root.AssemblyLinearVelocity
    if typeof(move)~='Vector3' or typeof(velocity)~='Vector3' then self.SpeedStatus='Waiting for movement'; return end
    local horizontal=Vector3.new(move.X,0,move.Z)
    if horizontal.Magnitude<0.001 then self.SpeedStatus='Velocity: idle'; return end
    if horizontal.Magnitude>1 then horizontal=horizontal.Unit end
    root.AssemblyLinearVelocity=Vector3.new(horizontal.X*c.Speed,velocity.Y,horizontal.Z*c.Speed)
    self.SpeedStatus='Horizontal velocity'
end
function Tools:Step()
    if not self.alive then return end
    local desired={}
    local function set(object,key,value)
        if not object then return end
        desired[object]=desired[object] or {}; desired[object][key]=value
    end
    local c,w=self.config.Character,self.config.World
    self:InteractionStep(set)
    local character=Players.LocalPlayer.Character
    local hum=humanoid(Players.LocalPlayer)
    self:StaminaStep(character,hum)
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
    self:SpeedStep(character,hum)
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
function Tools:RunScript(name)
    if not self.alive then return end
    local script=assert(self.Scripts[name],'Unknown tool')
    if self.launched[name] then self.library:SendNotification(name..' was already launched',4); return end
    self.launched[name]=true
    task.spawn(function()
        local ok,problem=pcall(function()
            local body=game:HttpGet(script.URL)
            assert(type(body)=='string' and body:find('%S') and not body:match('^%s*<'),'Invalid script response')
            local chunk,message=loadstring(body,'@Legit/External/'..name)
            assert(chunk,message)
            if self.alive then chunk() else self.launched[name]=nil end
        end)
        if not ok then
            self.launched[name]=nil
            if self.alive then self.library:SendNotification(name..': '..tostring(problem),6) end
        end
    end)
end
function Tools:Start()
    local function connect(signal,callback) table.insert(self.connections,signal:Connect(callback)) end
    if workspace.DescendantAdded then connect(workspace.DescendantAdded,function(object) self:TrackPrompt(object) end) end
    local ok,prompts=pcall(game.GetService,game,'ProximityPromptService')
    if ok and prompts.PromptShown then connect(prompts.PromptShown,function(prompt) self:TrackPrompt(prompt); self:Step() end) end
    connect(RunService.Heartbeat,function() self:Step() end)
    connect(Players.PlayerRemoving,function(player)
        if self.Selected==player then self.Selected=nil; self:SetSpectating(false) end
        self.engine.playerModes[player.UserId]=nil
    end)
end
function Tools:Destroy()
    if not self.alive then return end
    self.alive=false
    self:RescanStamina(); self:StaminaStatusTo('Disabled')
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self:Reconcile({})
    self.prompts=setmetatable({},{__mode='k'}); self.promptActive=false
    for name in pairs(self.effects) do self:Effect(name,'',false) end
    self.Selected,self.Spectating=nil,false
end
return Tools
