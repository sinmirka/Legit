-- C4 / rocket steering adapted from the reference. Launch the weapon normally.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Control={}
Control.__index=Control
local rockets={RPG_Rocket=true,GrenadeLauncherGrenade=true,AT4_Rocket=true,SBL_Rocket=true,
    Panzer_Rocket=true,FireworkLauncher_Rocket=true,Hallows_Rocket=true,Hallows_Rocket2=true}
function Control.new(config,engine,tools)
    return setmetatable({config=config,engine=engine,tools=tools,alive=true,pending={},lastShot=-math.huge,Status='Disabled'},Control)
end
function Control:WatchTool(tool)
    if self.tool==tool then return end
    if self.activation then self.activation:Disconnect() end
    self.tool=tool; self.lastShot=-math.huge
    if tool then self.activation=tool.Activated:Connect(function() self.lastShot=os.clock() end) end
end
function Control:Release(reason)
    local active=self.active; self.active=nil; self.engine.ProjectileControl=false
    if active then
        for _,mover in ipairs(active.Created) do mover:Destroy() end
        if active.Object.Parent then
            if active.Object.Massless==true then active.Object.Massless=active.Massless end
            for _,mover in ipairs(active.Suspended) do if not mover.Parent then pcall(function() mover.Parent=active.Object end) end end
        end
        if active.Root.Parent and active.Root.Anchored==true then active.Root.Anchored=active.Anchored end
        if active.Camera.CameraSubject==active.Object then
            active.Camera.CameraSubject=active.Subject and active.Subject.Parent and active.Subject or active.Humanoid
        end
    end
    self.Status=reason or 'Released'
end
function Control:TryControl(object)
    if self.active or not object.Parent or not object:IsA('BasePart') then return false end
    local c4=object.Name=='TransIgnore'
    if not ((c4 and self.config.C4) or (rockets[object.Name] and self.config.Rockets)) then return false end
    local character=Players.LocalPlayer.Character
    local hum=character and character:FindFirstChildOfClass('Humanoid')
    local root=character and character:FindFirstChild('HumanoidRootPart')
    local camera=workspace.CurrentCamera
    if not hum or hum.Health<=0 or not root or not camera or (object.Position-root.Position).Magnitude>25 then return false end
    local creator=object:FindFirstChild('Creator') or object:FindFirstChild('creator') or object:FindFirstChild('Owner')
    if creator and creator:IsA('ObjectValue') and creator.Value then
        if creator.Value~=Players.LocalPlayer and creator.Value~=character then return false end
    else
        local tool=character:FindFirstChildOfClass('Tool')
        if not tool or tool~=self.tool or os.clock()-self.lastShot>2 then return false end
        local name=tool.Name:lower()
        if c4 and name~='c4' then return false end
        if not c4 and not (name:find('rpg',1,true) or name:find('launcher',1,true) or name:find('at4',1,true)
            or name:find('panzer',1,true) or name:find('sbl',1,true)) then return false end
    end
    self.tools:SetSpectating(false)
    local active={Object=object,Character=character,Humanoid=hum,Root=root,Camera=camera,Subject=camera.CameraSubject,
        Anchored=root.Anchored,Massless=object.Massless,Created={},Suspended={},C4=c4}
    self.active=active; self.engine.ProjectileControl=true; self.engine:ResetTarget()
    -- Suspend existing movers rather than destroying game objects permanently.
    for _,child in ipairs(object:GetChildren()) do
        if child:IsA('BodyMover') or child:IsA('BodyForce') or child:IsA('BodyAngularVelocity')
            or child:IsA('BodyVelocity') or child:IsA('BodyPosition') or child:IsA('BodyGyro') then
            table.insert(active.Suspended,child); child.Parent=nil
        end
    end
    local mover=Instance.new(c4 and 'BodyVelocity' or 'BodyPosition')
    table.insert(active.Created,mover)
    mover.MaxForce=Vector3.new(1e9,1e9,1e9)
    if c4 then mover.Velocity=Vector3.zero else mover.P=10000; mover.D=100; mover.Position=object.Position end
    mover.Parent=object; active.Mover=mover
    local gyro=Instance.new('BodyGyro'); table.insert(active.Created,gyro)
    gyro.MaxTorque=Vector3.new(1e9,1e9,1e9); gyro.P=10000; gyro.D=100; gyro.CFrame=object.CFrame; gyro.Parent=object
    active.Gyro=gyro
    object.Massless=true; root.Anchored=true; camera.CameraSubject=object
    self.Status='Controlling '..object.Name..' (X to release)'
    return true
end
function Control:Step(dt)
    if not self.alive then return end
    local character=Players.LocalPlayer.Character
    self:WatchTool((self.config.C4 or self.config.Rockets) and character and character:FindFirstChildOfClass('Tool') or nil)
    local active=self.active
    if active then
        if not active.Object.Parent or character~=active.Character or active.Humanoid.Health<=0
            or workspace.CurrentCamera~=active.Camera or not self.engine.focused
            or not (active.C4 and self.config.C4 or not active.C4 and self.config.Rockets) then self:Release('Released'); return end
        if active.Camera.CameraSubject~=active.Object then self:Release('Camera changed'); return end
        local movement=active.Camera.CFrame.LookVector+active.Humanoid.MoveDirection
        if movement.Magnitude>0.001 then movement=movement.Unit end
        local speed=self.config.Speed
        active.Gyro.CFrame=active.Camera.CFrame
        if active.C4 then active.Mover.Velocity=movement*speed
        else active.Mover.Position=active.Object.Position+movement*speed*math.min(dt or 1/60,0.1) end
    else
        self.Status=(self.config.C4 or self.config.Rockets) and 'Waiting for your launched projectile' or 'Disabled'
        for index=#self.pending,1,-1 do
            local entry=self.pending[index]
            if not entry.Object.Parent or os.clock()-entry.Time>0.75 then table.remove(self.pending,index)
            elseif self:TryControl(entry.Object) then table.remove(self.pending,index); break end
        end
    end
end
function Control:Start()
    self.added=workspace.DescendantAdded and workspace.DescendantAdded:Connect(function(object)
        if object.Name=='C4Explosion' and self.active and self.active.C4 then self:Release('C4 exploded') end
        if (self.config.C4 or self.config.Rockets) and (object.Name=='TransIgnore' or rockets[object.Name]) and #self.pending<32 then
            table.insert(self.pending,{Object=object,Time=os.clock()})
        end
    end)
    self.input=Input.InputBegan:Connect(function(input)
        if input.KeyCode==Enum.KeyCode.X and not Input:GetFocusedTextBox() then self.pending={}; self:Release('Released by X') end
    end)
    self.heartbeat=RunService.Heartbeat:Connect(function(dt)
        local ok,problem=pcall(self.Step,self,dt)
        if not ok then self:Release('Control error: '..tostring(problem)) end
    end)
end
function Control:Destroy()
    self.alive=false; self:Release('Unloaded'); self:WatchTool(nil); self.pending={}
    for _,connection in pairs({added=self.added,input=self.input,heartbeat=self.heartbeat}) do connection:Disconnect() end
end
return Control
