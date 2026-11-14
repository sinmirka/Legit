-- Redirect real melee hitbox rays; the game still performs hit registration.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local MeleeAura={}
MeleeAura.__index=MeleeAura
local weapons={Fists=true,Knuckledusters=true,Nunchucks=true,Shiv=true,Bat=true,
    ['Metal-Bat']=true,Chainsaw=true,Balisong=true,Rambo=true,Shovel=true,
    Sledgehammer=true,Katana=true,Wrench=true,['Fire Axe']=true}
local function rig(player)
    local character=player.Character
    if not character or not character:IsDescendantOf(workspace) then return end
    local humanoid=character:FindFirstChildOfClass('Humanoid')
    local root=character:FindFirstChild('HumanoidRootPart')
    if humanoid and humanoid.Health>0 and root and root:IsA('BasePart') then return character,humanoid,root end
end
local function finite(vector)
    if typeof(vector)~='Vector3' then return false end
    for _,n in ipairs({vector.X,vector.Y,vector.Z}) do
        if n~=n or math.abs(n)==math.huge then return false end
    end
    return true
end
function MeleeAura.new(config,engine,library)
    local self=setmetatable({config=config,engine=engine,library=library,alive=true,
        nextAttack=0,swingUntil=0,Status='Disabled'},MeleeAura)
    self.ray=RaycastParams.new()
    self.ray.FilterType=Enum.RaycastFilterType.Exclude
    self.ray.IgnoreWater=true
    return self
end
function MeleeAura:Reset()
    self.target,self.swingUntil=nil,0
end
function MeleeAura:Blocked()
    return not self.alive or not self.config.Enabled or not self.engine.focused
        or Input:GetFocusedTextBox()~=nil or self.library:IsInteracting()
        or (self.config.PauseMenu and self.library.open)
end
function MeleeAura:Candidate(player,root)
    local s=self.config
    if not self.engine:Allowed(player,s) then return end
    local character,humanoid,targetRoot=rig(player)
    if not character or humanoid.Health<s.MinHealth then return end
    if s.SkipForceField and character:FindFirstChildOfClass('ForceField') then return end
    local part=character:FindFirstChild(s.Part)
    if not part and s.Part=='UpperTorso' then part=character:FindFirstChild('Torso') end
    if not part or not part:IsA('BasePart') then return end
    local delta=part.Position-root.Position
    if delta.Magnitude>s.Range or delta.Magnitude<0.001 then return end
    if s.WallCheck then
        local hit=workspace:Raycast(root.Position,delta,self.ray)
        if hit and not hit.Instance:IsDescendantOf(character) then return end
    end
    return {Player=player,Part=part,Score=s.Priority=='Lowest health' and humanoid.Health or delta.Magnitude}
end
function MeleeAura:Equip(tool)
    if self.tool==tool then return end
    if self.activation then self.activation:Disconnect(); self.activation=nil end
    self:Reset()
    self.tool,self.nextAttack=tool,0
    if tool then
        self.activation=tool.Activated:Connect(function()
            if not self:Blocked() then self.swingUntil=os.clock()+self.config.SwingWindow end
        end)
    end
end
function MeleeAura:InstallHook()
    if self.hook then return true end
    -- One dispatcher per executor session avoids hook chains on repeated loads.
    local env=getgenv()
    local state=env.LegitMeleeRaycastHook
    if not state then
        if type(hookmetamethod)~='function' or type(getnamecallmethod)~='function'
            or type(checkcaller)~='function' or type(getcallingscript)~='function' then
            self.Status='Unavailable: executor needs Raycast hook APIs'
            return false
        end
        state={}
        local previous
        local wrap=type(newcclosure)=='function' and newcclosure or function(fn) return fn end
        local ok,result=pcall(function()
            return hookmetamethod(game,'__namecall',wrap(function(receiver,...)
                local owner=state.Owner
                if owner and getnamecallmethod()=='Raycast' and receiver==workspace and not checkcaller() then
                    local args=table.pack(...)
                    local succeeded,direction=pcall(owner.Redirect,owner,getcallingscript(),args[1],args[2])
                    if succeeded and direction then
                        args[2]=direction
                        return previous(receiver,table.unpack(args,1,args.n))
                    end
                end
                return previous(receiver,...)
            end))
        end)
        if not ok or type(result)~='function' then
            self.Status='Unavailable: Raycast hook installation failed'
            return false
        end
        previous=result
        env.LegitMeleeRaycastHook=state
    end
    state.Owner=self
    self.hook=state
    return true
end
function MeleeAura:Redirect(caller,origin,direction)
    if self:Blocked() or not self.target or os.clock()>self.swingUntil then return end
    if not finite(origin) or not finite(direction) or direction.Magnitude<0.001 then return end
    local character,_,root=rig(Players.LocalPlayer)
    if not character or not self.tool or self.tool.Parent~=character or not self.tool.Enabled then return end
    -- Only equipped weapon scripts or a named melee hitbox module may redirect.
    -- Short rays and nearby origins further exclude camera, visibility and gun rays.
    if not caller or (not caller:IsDescendantOf(self.tool)
        and not caller.Name:lower():find('raycasthitbox',1,true)) then return end
    if direction.Magnitude>self.config.Range+6 or (origin-root.Position).Magnitude>self.config.Range+6 then return end
    self.ray.FilterDescendantsInstances={character}
    local candidate=self:Candidate(self.target.Player,root)
    if not candidate then return end
    local delta=candidate.Part.Position-origin
    if delta.Magnitude<0.001 or delta.Magnitude>self.config.Range+6 then return end
    return delta.Unit*math.max(direction.Magnitude,delta.Magnitude+0.1)
end
function MeleeAura:Step(now)
    if self:Blocked() then self:Reset(); self.Status=self.config.Enabled and 'Paused' or 'Disabled'; return end
    if not self:InstallHook() then self:Reset(); return end
    local character,_,root=rig(Players.LocalPlayer)
    local tool=character and character:FindFirstChildOfClass('Tool')
    if not tool or not weapons[tool.Name] or not tool.Enabled then
        self:Equip(nil); self:Reset(); self.Status='Equip a supported melee tool'; return
    end
    self:Equip(tool)
    self.ray.FilterDescendantsInstances={character}
    local best
    for _,player in ipairs(Players:GetPlayers()) do
        local candidate=self:Candidate(player,root)
        if candidate and (not best or self.engine:TargetRank(player)<self.engine:TargetRank(best.Player)
            or (self.engine:TargetRank(player)==self.engine:TargetRank(best.Player) and (candidate.Score<best.Score
                or (candidate.Score==best.Score and player.UserId<best.Player.UserId)))) then best=candidate end
    end
    self.target=best
    self.Status=best and ('Target: @'..best.Player.Name) or 'No target in range'
    if best and self.config.AutoAttack and now>=self.nextAttack then
        self.nextAttack=now+self.config.Interval
        self.swingUntil=now+self.config.SwingWindow
        local ok=pcall(function() tool:Activate() end)
        if not ok then self:Reset(); self.Status='Tool activation failed' end
    end
end
function MeleeAura:Start()
    if self.connection then return end
    self.connection=RunService.Heartbeat:Connect(function() self:Step(os.clock()) end)
end
function MeleeAura:Destroy()
    self.alive=false
    self:Equip(nil); self:Reset()
    if self.connection then self.connection:Disconnect(); self.connection=nil end
    -- Keep a transparent dispatcher: restoring __namecall could erase another script's hook.
    if self.hook and self.hook.Owner==self then self.hook.Owner=nil end
end
return MeleeAura
