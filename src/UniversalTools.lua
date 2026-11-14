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
    self:Reconcile(desired)
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

end
function Tools:Destroy()
    if not self.alive then return end
    self.alive=false
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self:Reconcile({})
    self.Selected,self.Spectating=nil,false
end
return Tools
