-- Redirect real melee hitbox rays; the game still performs hit registration.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local MeleeAura={}
MeleeAura.__index=MeleeAura
-- Criminality Wiki Category:Melees, checked 2026-11-14; includes event/legacy entries.
MeleeAura.WeaponNames={'Wrench','Crowbar','Golf Club','Shovel','Bat','Baton','Metal Bat',
    'Sledgehammer','Candy Crowbar','Hammer','Shiv','Bayonet','Taiga','Balisong','Rambo',
    'Machete','Katana','Cursed Dagger',"Slayer's Sword II",'Scythe','Fallen Sword',
    'ERADICATOR','ERADICATOR II','Black Bayonet',"Hallow's Blade",'Hatchet',
    "Slayer's Sword",'Knuckledusters','Nunchucks','Fists','Fire Axe','Chainsaw',
    'Clippers','X-Fist','Sabre'}
local function weaponKey(name) return (name:lower():gsub('[%s%p]','')) end
local weapons={}
local fistFamilies={fists=true,zombiefists=true,infectedfists=true,xfist=true,xfists=true}
for _,name in ipairs(MeleeAura.WeaponNames) do weapons[weaponKey(name)]=true end
for _,alias in ipairs({"Slayer's I","Slayer's II",'Military Machete','Necromancer Scythe',
    'Cash Cane','Golden Katana','Voidedge Katana','RIPPER Chainsaw','COPE Axe'}) do
    weapons[weaponKey(alias)]=true
end
function MeleeAura:IsMeleeTool(tool)
    if not tool then return false end
    local key=weaponKey(tool.Name)
    if weapons[key] or fistFamilies[key:match('^(%a+)%d*$')] then return true end
    -- Observed Criminality tool layout; supports renamed/skinned melee tools.
    -- Called by Step only, never by the Raycast dispatcher.
    local module=tool:FindFirstChild('Melee')
    local animations=tool:FindFirstChild('AnimsFolder')
    local handle=tool:FindFirstChild('WeaponHandle')
    return module~=nil and module:IsA('ModuleScript') and animations~=nil and animations:IsA('Folder')
        and handle~=nil and handle:IsA('BasePart')
end
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
        nextAttack=0,swingUntil=0,Status='Disabled',Counters={},lastSummary=0,logger=engine.Logger},MeleeAura)
    self.ray=RaycastParams.new()
    self.ray.FilterType=Enum.RaycastFilterType.Exclude
    self.ray.IgnoreWater=true
    return self
end
function MeleeAura:Count(reason)
    if self.logger and self.logger.settings.Enabled then self.Counters[reason]=(self.Counters[reason] or 0)+1 end
end
function MeleeAura:Log(level,event,message,data,interval)
    if self.logger then self.logger:Write(level,'Melee',event,message,data,interval) end
end
function MeleeAura:StatusTo(value)
    self.Status=value
    if self.logger then self.logger:State('Melee','status',value) end
end
function MeleeAura:BlockReason()
    if not self.alive then return 'unloaded' end
    if not self.config.Enabled then return 'disabled' end
    if not self.engine.focused then return 'unfocused' end
    if Input:GetFocusedTextBox() then return 'typing' end
    if self.library:IsInteracting() then return 'UI interaction' end
    if self.config.PauseMenu and self.library.open then return 'menu open' end
end
function MeleeAura:Reset()
    self.target,self.prepared,self.swingUntil=nil,nil,0
end
function MeleeAura:Blocked()
    return self:BlockReason()~=nil
end
function MeleeAura:DownedState(player,character,humanoid)
    -- Resolve game markers in Step only; the hook later reads cached BoolValue.Value.
    local flags={}
    local downed=false
    local statsRoot=ReplicatedStorage:FindFirstChild('CharStats')
    local stats=statsRoot and statsRoot:FindFirstChild(player.Name)
    local containers={character,humanoid}
    if stats then table.insert(containers,stats) end
    for _,container in ipairs(containers) do
        local flag=container:FindFirstChild('Downed')
        if flag and flag:IsA('BoolValue') then
            table.insert(flags,flag)
            if flag.Value==true then downed=true end
        end
        if container:GetAttribute('Downed')==true then downed=true end
    end
    local state=humanoid:GetState()
    if humanoid.PlatformStand or state==Enum.HumanoidStateType.Ragdoll
        or state==Enum.HumanoidStateType.FallingDown then downed=true end
    return downed,flags
end
function MeleeAura:Candidate(player,root)
    local s=self.config
    if player==Players.LocalPlayer then return nil,'self' end
    if not self.engine:Allowed(player,s) then return nil,'team/friend/priority' end
    local character,humanoid,targetRoot=rig(player)
    if not character then return nil,'rig/dead' end
    local flags,downed
    if s.SkipDowned then
        downed,flags=self:DownedState(player,character,humanoid)
        if downed and humanoid.Health<=15 then return nil,'downed/ragdoll <=15 HP' end
    end
    if humanoid.Health<s.MinHealth then return nil,'minimum HP' end
    if s.SkipForceField and character:FindFirstChildOfClass('ForceField') then return nil,'ForceField' end
    local part=character:FindFirstChild(s.Part)
    if not part and s.Part=='UpperTorso' then part=character:FindFirstChild('Torso') end
    if not part or not part:IsA('BasePart') then return nil,'body part' end
    local delta=part.Position-root.Position
    if delta.Magnitude>s.Range or delta.Magnitude<0.001 then return nil,'range' end
    if s.WallCheck then
        local hit=workspace:Raycast(root.Position,delta,self.ray)
        if hit and not hit.Instance:IsDescendantOf(character) then return nil,'wall' end
    end
    return {Player=player,Character=character,Humanoid=humanoid,Part=part,DownedFlags=flags,Downed=downed,
        Score=s.Priority=='Lowest health' and humanoid.Health or delta.Magnitude}
end
function MeleeAura:Equip(tool)
    if self.tool==tool then return end
    if self.activation then self.activation:Disconnect(); self.activation=nil end
    self:Reset()
    self.tool,self.nextAttack=tool,0
    self:Log('info','equipped',tool and tool.Name or 'No supported tool')
    if tool then
        self.activation=tool.Activated:Connect(function()
            if not self:Blocked() then
                self.swingUntil=os.clock()+self.config.SwingWindow
                self:Count('swing.Activated')
                self:Log('trace','swing','Tool.Activated observed',nil,0.5)
            end
        end)
    end
end
function MeleeAura:CapabilityProblem()
    local missing={}
    for _,name in ipairs({'hookmetamethod','getnamecallmethod','checkcaller','getcallingscript'}) do
        if type(getfenv()[name])~='function' then table.insert(missing,name) end
    end
    if #missing>0 then return 'Unavailable: missing '..table.concat(missing,', ') end
end
function MeleeAura:InstallHook()
    if self.hook then return true end
    -- One dispatcher per executor session avoids hook chains on repeated loads.
    local env=getgenv()
    local state=env.LegitMeleeRaycastHook
    -- Upgrade the old dispatcher once; leave its owner empty so it stays transparent.
    if state and state.Version~=5 then state.Owner=nil; state.SilentOwner=nil; state=nil end
    if not state then
        local unavailable=self:CapabilityProblem()
        if unavailable then
            self:StatusTo(unavailable)
            self:Log('error','capabilities',self.Status,nil,5)
            return false
        end
        state={Version=5}
        local previous
        local wrap=type(newcclosure)=='function' and newcclosure or function(fn) return fn end
        local ok,result=pcall(function()
            return hookmetamethod(game,'__namecall',wrap(function(receiver,...)
                -- Capture before any work. Never call an Instance method in this
                -- dispatcher: it can replace the executor's active namecall method.
                local method=getnamecallmethod()
                local owner=state.Owner
                local silent=state.SilentOwner
                local meleeActive=owner and owner.alive and owner.config.Enabled
                local silentActive=silent and silent.alive and silent.config.Enabled
                if method=='Raycast' and (meleeActive or silentActive) and receiver==workspace and not checkcaller() then
                    local args=table.pack(...)
                    local function redirect(feature)
                        local succeeded,direction,trace=pcall(function()
                            feature:Count('ray.seen')
                            return feature:Redirect(getcallingscript(),args[1],args[2],args[3])
                        end)
                        if not succeeded then
                            feature:Count('hook.error')
                            feature:Log('error','hook',tostring(direction),nil,1)
                        else return direction,trace end
                    end
                    local direction=meleeActive and redirect(owner)
                    local chosen=direction and owner
                    local trace
                    if not direction and silentActive then direction,trace=redirect(silent); chosen=direction and silent end
                    if direction or trace then
                        if direction then args[2]=direction end
                        local results=table.pack(previous(receiver,table.unpack(args,1,args.n)))
                        if chosen then pcall(chosen.ObserveHit,chosen,results[1]) end
                        if trace then pcall(silent.RecordTrace,silent,trace,results[1]) end
                        return table.unpack(results,1,results.n)
                    end
                end
                return previous(receiver,...)
            end))
        end)
        if not ok or type(result)~='function' then
            self:StatusTo('Unavailable: Raycast hook installation failed')
            self:Log('error','hook.install',tostring(result),nil,5)
            return false
        end
        previous=result
        env.LegitMeleeRaycastHook=state
    end
    state.Owner=self
    self.hook=state
    self:Log('info','hook.install','Raycast dispatcher attached')
    return true
end
local function pathOf(object)
    if not object then return 'nil' end
    local names={}
    for _=1,32 do
        if not object then break end
        table.insert(names,1,object.Name or '?')
        object=object.Parent
    end
    return table.concat(names,'.')
end
local function inside(object,parent)
    for _=1,64 do
        if not object then return false end
        if object==parent then return true end
        object=object.Parent
    end
    return false
end
function MeleeAura:ObserveHit(result)
    self:Count('ray.redirected')
    if not self.logger or not self.logger.settings.Enabled or not self.logger.settings.CaptureRays then return end
    local now=os.clock()
    if now<(self.nextHitTrace or 0) then return end
    self.nextHitTrace=now+0.5
    local hit=(typeof(result)=='RaycastResult' or type(result)=='table') and result.Instance
    self:Log('trace','ray.result','Client raycast result; not proof of server damage',
        {Hit=pathOf(hit)},0.5)
end
function MeleeAura:Redirect(caller,origin,direction)
    -- This path runs inside __namecall. Use only properties and Lua data prepared
    -- by Step; Input, FindFirstChild, IsDescendantOf and visibility rays belong there.
    local function reject(reason) self:Count('ray.skip.'..reason); return nil end
    if not self.alive or not self.config.Enabled or not self.engine.focused
        or (self.config.PauseMenu and self.library.open) then return reject('paused') end
    local prepared=self.prepared
    if not self.target or not prepared then return reject('no target') end
    if os.clock()>self.swingUntil then return reject('no swing window') end
    if not finite(origin) or not finite(direction) or direction.Magnitude<0.001 then return reject('invalid vector') end
    local character,root=prepared.Character,prepared.Root
    if Players.LocalPlayer.Character~=character or prepared.Humanoid.Health<=0
        or not self.tool or self.tool~=prepared.Tool or self.tool.Parent~=character
        or not self.tool.Enabled then return reject('tool/rig') end
    -- Only equipped weapon scripts or a named melee hitbox module may redirect.
    -- Short rays and nearby origins further exclude camera, visibility and gun rays.
    if direction.Magnitude>self.config.Range+6 or (origin-root.Position).Magnitude>self.config.Range+6 then return reject('ray bounds') end
    local now=os.clock()
    if self.logger and self.logger.settings.Enabled and self.logger.settings.CaptureRays
        and now>=(self.nextCallerTrace or 0) then
        self.nextCallerTrace=now+0.5
        self:Log('trace','ray.caller','Nearby game Raycast observed',
            {Caller=pathOf(caller),Length=string.format('%.2f',direction.Magnitude)},0.5)
    end
    if not caller or (not inside(caller,self.tool)
        and not caller.Name:lower():find('raycasthitbox',1,true)) then return reject('caller mismatch') end
    local candidate=prepared.Target
    if self.config.SkipDowned and candidate.Humanoid.Health<=15 then
        if candidate.Downed or candidate.Humanoid.PlatformStand then return reject('downed/ragdoll') end
        for _,flag in ipairs(candidate.DownedFlags or {}) do
            if flag.Value==true then return reject('downed/ragdoll') end
        end
    end
    if candidate~=self.target or candidate.Player.Parent~=Players
        or candidate.Player.Character~=candidate.Character or candidate.Humanoid.Health<=0
        or candidate.Humanoid.Health<self.config.MinHealth or candidate.Part.Parent~=candidate.Character
        or (candidate.Part.Position-root.Position).Magnitude>self.config.Range then return reject('target invalidated') end
    local delta=candidate.Part.Position-origin
    if delta.Magnitude<0.001 or delta.Magnitude>self.config.Range+6 then return reject('target ray bounds') end
    return delta.Unit*math.max(direction.Magnitude,delta.Magnitude+0.1)
end
function MeleeAura:Step(now)
    local unavailable=self.config.Enabled and self:CapabilityProblem()
    if unavailable then
        self:Reset(); self:StatusTo(unavailable)
        self:Log('error','capabilities',unavailable,nil,5)
        return
    end
    local blocked=self:BlockReason()
    if blocked then self:Reset(); self:StatusTo(self.config.Enabled and ('Paused: '..blocked) or 'Disabled'); return end
    if not self:InstallHook() then self:Reset(); return end
    local character,humanoid,root=rig(Players.LocalPlayer)
    local tool=character and character:FindFirstChildOfClass('Tool')
    if not character then self:Equip(nil); self:Reset(); self:StatusTo('Waiting for local character'); return end
    local meleeTool=self:IsMeleeTool(tool)
    if not meleeTool or not tool.Enabled then
        self:Equip(nil); self:Reset()
        self:StatusTo(not tool and 'Equip a supported melee tool' or (not meleeTool and ('Unsupported tool: '..tool.Name) or ('Tool disabled: '..tool.Name)))
        return
    end
    self:Equip(tool)
    self.ray.FilterDescendantsInstances={character}
    local best
    for _,player in ipairs(Players:GetPlayers()) do
        local candidate,reason=self:Candidate(player,root)
        if reason and reason~='self' then self:Count('target.skip.'..reason) end
        if candidate and (not best or self.engine:TargetRank(player)<self.engine:TargetRank(best.Player)
            or (self.engine:TargetRank(player)==self.engine:TargetRank(best.Player) and (candidate.Score<best.Score
                or (candidate.Score==best.Score and player.UserId<best.Player.UserId)))) then best=candidate end
    end
    self.target=best
    self.prepared=best and {Character=character,Humanoid=humanoid,Root=root,Tool=tool,Target=best} or nil
    self:StatusTo(best and ('Target: @'..best.Player.Name) or 'No target in range')
    if self.logger and self.logger.settings.Enabled and now-self.lastSummary>=2 then
        self.lastSummary=now
        self:Log('info','summary','Cumulative counters (target skips count heartbeat evaluations)',self.Counters)
    end
    if best and self.config.AutoAttack and now>=self.nextAttack then
        self.nextAttack=now+self.config.Interval
        self.swingUntil=now+self.config.SwingWindow
        self:Count('activation.attempted')
        local ok,problem=pcall(function() tool:Activate() end)
        if not ok then
            self:Reset(); self:StatusTo('Tool activation failed')
            self:Log('error','activation',tostring(problem),nil,1)
        end
    end
end
function MeleeAura:Start()
    if self.connection then return end
    local nextUpdate=0
    self.connection=RunService.Heartbeat:Connect(function()
        local now=os.clock()
        if now<nextUpdate then return end
        nextUpdate=now+1/30
        local ok,problem=xpcall(function() self:Step(now) end,debug.traceback)
        if not ok then
            self:Reset(); self:StatusTo('Error in melee update')
            self:Log('error','heartbeat',tostring(problem),nil,1)
        end
    end)
end
function MeleeAura:Destroy()
    self.alive=false
    self:Equip(nil); self:Reset()
    if self.connection then self.connection:Disconnect(); self.connection=nil end
    -- Keep a transparent dispatcher: restoring __namecall could erase another script's hook.
    if self.hook and self.hook.Owner==self then self.hook.Owner=nil end
end
return MeleeAura
