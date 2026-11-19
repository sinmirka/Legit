local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Toys={}
Toys.__index=Toys
function Toys.new(config)
    return setmetatable({config=config,alive=true,connections={},Status='Disabled'},Toys)
end
function Toys:Stop()
    if self.track then pcall(self.track.Stop,self.track); pcall(self.track.Destroy,self.track); self.track=nil end
end
function Toys:Remove()
    self:Stop()
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections={}
    if self.tool then local tool=self.tool; self.tool=nil; tool:Destroy() end
end
function Toys:Activate()
    if self.track then self:Stop(); self.Status='Jerk Tool ready'; return end
    local character=Players.LocalPlayer.Character
    local humanoid=character and character:FindFirstChildOfClass('Humanoid')
    if not self.alive or not self.config.Jerk or not humanoid or humanoid.Health<=0 then return end
    local animation=Instance.new('Animation')
    animation.AnimationId=humanoid.RigType==Enum.HumanoidRigType.R15 and 'rbxassetid://698251653' or 'rbxassetid://72042024'
    local animator=humanoid:FindFirstChildOfClass('Animator') or humanoid
    local ok,track=pcall(animator.LoadAnimation,animator,animation)
    animation:Destroy()
    if not ok then self.Status='Animation unavailable: '..tostring(track); return end
    self.track=track; track.Looped=true
    local played,problem=pcall(track.Play,track)
    if not played then self:Stop(); self.Status='Animation unavailable: '..tostring(problem); return end
    self.Status='Jerk animation playing; activate again to stop'
end
function Toys:Step()
    if not self.alive then return end
    if not self.config.Jerk then self:Remove(); self.Status='Disabled'; return end
    local character=Players.LocalPlayer.Character
    local backpack=Players.LocalPlayer:FindFirstChildOfClass('Backpack')
    if self.character~=character then self:Remove(); self.character=character end
    local humanoid=character and character:FindFirstChildOfClass('Humanoid')
    if not humanoid or humanoid.Health<=0 then self:Stop() end
    if self.tool and self.tool.Parent~=backpack and self.tool.Parent~=character then self:Remove() end
    if not self.tool and backpack then
        local tool=Instance.new('Tool'); tool.Name='Jerk'; tool.RequiresHandle=false; tool.CanBeDropped=false
        self.tool=tool
        table.insert(self.connections,tool.Activated:Connect(function() self:Activate() end))
        if tool.Unequipped then table.insert(self.connections,tool.Unequipped:Connect(function() self:Stop() end)) end
        table.insert(self.connections,tool.Destroying:Connect(function() self:Stop() end))
        tool.Parent=backpack; self.Status='Jerk Tool ready'
    elseif not backpack then self.Status='Waiting for backpack' end
end
function Toys:Start()
    local nextStep=0
    self.heartbeat=RunService.Heartbeat:Connect(function()
        if os.clock()<nextStep then return end; nextStep=os.clock()+0.25
        local ok,problem=pcall(self.Step,self)
        if not ok then self:Stop(); self.Status='Tool error: '..tostring(problem) end
    end)
end
function Toys:Destroy()
    self.alive=false; self:Remove()
    if self.heartbeat then self.heartbeat:Disconnect() end
end
return Toys
