-- Update Gun's shared client/server direction list, then observe real FastCast signals.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Storage=game:GetService('ReplicatedStorage')
local Silent={}
Silent.__index=Silent
local function finite(v)
    return typeof(v)=='Vector3' and v.X==v.X and v.Y==v.Y and v.Z==v.Z
        and math.abs(v.X)<math.huge and math.abs(v.Y)<math.huge and math.abs(v.Z)<math.huge
end
local function inside(object,parent)
    for _=1,64 do
        if not object then return false end
        if object==parent then return true end
        object=object.Parent
    end
    return false
end
-- Shared per-coroutine guard spans the original call too: FastCast entry points
-- can delegate to one another, and Effects can synchronously emit shot signals.
local function guardedCall(state,original,callback,...)
    local thread=coroutine.running() or state
    if state.Busy[thread] then return original(...) end
    state.Busy[thread]=true
    local args=table.pack(...)
    local ok,problem=pcall(callback,args)
    if not ok and state.Owner then state.Owner:Log('error','adapter',tostring(problem),nil,1) end
    local results=table.pack(pcall(original,table.unpack(args,1,args.n)))
    state.Busy[thread]=nil
    if not results[1] then error(results[2],0) end
    return table.unpack(results,2,results.n)
end
function Silent.new(config,engine,library,melee)
    local self=setmetatable({config=config,engine=engine,library=library,melee=melee,logger=engine.Logger,
        alive=true,Counters={},Status='Disabled',ShotStatus='Waiting for Visualize event',lastSummary=0,
        traceQueue={},shots={},tracePool={},projectiles={},casters={}},Silent)
    self.circle=engine.Drawing.new('Circle')
    self.circle.Filled=false; self.circle.Thickness=1; self.circle.ZIndex=31; self.circle.Visible=false
    self.ray=RaycastParams.new(); self.ray.FilterType=Enum.RaycastFilterType.Exclude; self.ray.IgnoreWater=true
    return self
end
function Silent:Count(reason)
    if self.logger and self.logger.settings.Enabled then self.Counters[reason]=(self.Counters[reason] or 0)+1 end
end
function Silent:Log(level,event,message,data,interval)
    if self.logger then self.logger:Write(level,'Silent',event,message,data,interval) end
end
function Silent:SetStatus(value)
    self.Status=value
    if self.logger then self.logger:State('Silent','status',value) end
end
function Silent:Reset()
    if self.raycastHook and self.raycastHook.SilentOwner==self then self.raycastHook.SilentOwner=nil end
    self.visualizeGeneration=(self.visualizeGeneration or 0)+1
    self.cycleVisited=nil
    self:ReleaseAutoFire()
    self.AutoFireStatus=self.config.AutoFire and 'Waiting for target' or 'Disabled'
    self.prepared,self.gunContext=nil,nil; self.circle.Visible=false
    self.traceQueue={}; self.shots={}
    self.projectiles={}; self.launches={}
    for _,entry in ipairs(self.casters) do
        for _,connection in ipairs(entry.Connections) do connection:Disconnect() end
    end
    self.casters={}
    for _,slot in ipairs(self.tracePool) do
        slot.Sent.Enabled=false; slot.Original.Enabled=false; slot.Hit.Transparency=1
    end
    if self.targetDot then self.targetDot.Visible=false; self.targetLabel.Visible=false end
end
function Silent:Equip(tool,skipBallistics)
    if self.tool==tool then return end
    self.tool=tool; self:Reset(); self.ballistics=nil
    local config=not skipBallistics and tool and tool:FindFirstChild('Config')
    if config then
        local ok,value=pcall(require,config)
        if ok and type(value)=='table' and type(value.BulletSettings)=='table' then
            local b=value.BulletSettings
            if type(b.Velocity)=='number' and b.Velocity>0 then self.ballistics={Velocity=b.Velocity,Acceleration=b.Acceleration} end
        end
    end
end
function Silent:FastCastModule()
    local modules=Storage:FindFirstChild('NewModules')
    local shared=modules and modules:FindFirstChild('Shared')
    local services=shared and shared:FindFirstChild('Services')
    local module=services and services:FindFirstChild('FastCastRedux')
    return module and module:IsA('ModuleScript') and module or nil
end
function Silent:CapabilityProblem()
    if self.config.Universal then return self.melee:RaycastCapabilityProblem(true) end
    if self:VisualizeObjects() then return end
    if type(hookfunction)=='function' and type(checkcaller)=='function' then return end
    return 'Unavailable: missing hookfunction/checkcaller and no Visualize event'
end
-- Criminality's Visualize event is also available in executors without hooks.
function Silent:VisualizeObjects()
    local events2=Storage:FindFirstChild('Events2')
    local visualize=events2 and events2:FindFirstChild('Visualize')
    local events=Storage:FindFirstChild('Events')
    local hit=events and events:FindFirstChild('ZFKLF__H')
    if visualize and visualize:IsA('BindableEvent') and hit and hit:IsA('RemoteEvent') then return visualize,hit end
end
function Silent:InstallVisualize()
    local visualize,hit=self:VisualizeObjects()
    if not visualize then return false end
    if self.visualizeObject==visualize and self.hitRemote==hit then return true end
    if self.visualizeConnection then self.visualizeConnection:Disconnect() end
    self.visualizeObject,self.hitRemote=visualize,hit
    self.visualizeConnection=visualize.Event:Connect(function(...)
        local ok,problem=pcall(self.Visualize,self,...)
        if not ok then
            self.ShotStatus='Error handling Visualize: '..tostring(problem)
            self:Log('error','visualize',tostring(problem),nil,1)
        end
    end)
    return true
end
function Silent:Visualize(_,identifier,_,tool,_,origin,directions)
    local s=self.config
    local function skip(reason)
        self.ShotStatus='Skipped: '..reason
        self:Count('visualize.skip.'..reason)
        self:Log('info','visualize.skip',reason,{Shot=identifier})
    end
    self:Count('visualize.seen')
    if not self.alive or not s.Enabled or s.Universal or self.engine.ProjectileControl or not self.engine.focused
        or Input:GetFocusedTextBox() or self.library:IsInteracting() or self.library:IsPointerOverUI()
        or (s.PauseMenu and self.library.open) then return skip('paused by input / menu / mode') end
    local character=Players.LocalPlayer.Character
    if not character or character:FindFirstChildOfClass('Tool')~=tool
        then return skip('foreign or unequipped tool') end
    if character:FindFirstChildOfClass('ForceField') then return skip('local ForceField') end
    if type(identifier)~='string' and type(identifier)~='number' then return skip('invalid shot identifier') end
    -- The reference treats absent/empty pellet data as one pellet. Only its
    -- count is part of the hit protocol; original directions are optional.
    local pelletCount=type(directions)=='table' and math.max(1,#directions) or 1
    if pelletCount>128 then return skip('too many pellets') end
    local original=type(directions)=='table' and directions[1]
    self:Log('info','shot.visualize','Visualize received',{Shot=identifier,Weapon=tool.Name,Pellets=pelletCount})
    -- Refresh filters at the actual shot, including walls and friend changes.
    local p=self.gunContext
    if not p or not p.Target or p.Tool~=tool then return skip('no prepared target / gun context') end
    local target,reason=self.engine:Candidate(p.Target.Player,workspace.CurrentCamera,p.Root,s,self.ray)
    if not target then return skip('target: '..tostring(reason)) end
    if s.SkipDowned then
        local hum=p.Target.Character:FindFirstChildOfClass('Humanoid')
        if self.melee:DownedState(p.Target.Player,p.Target.Character,hum) and hum.Health<=15 then return skip('target downed') end
    end
    if not finite(origin) then
        local handle=tool:FindFirstChild('WeaponHandle',true) or tool:FindFirstChild('Handle',true)
        local muzzle=handle and (handle:FindFirstChild('FirePoint',true) or handle:FindFirstChild('Muzzle',true))
        origin=muzzle and (muzzle:IsA('Attachment') and muzzle.WorldPosition or muzzle.Position) or p.CameraOrigin
    end
    local aim=target.Position
    if not finite(origin) or not finite(aim) or (origin-p.Root.Position).Magnitude>s.OriginRadius
        or (aim-origin).Magnitude<0.001 then return skip('invalid / distant origin') end
    self.visualized=self.visualized or {}
    local now=os.clock()
    local count=0
    for id,time in pairs(self.visualized) do
        if now-time>5 then self.visualized[id]=nil else count+=1 end
    end
    if self.visualized[identifier] or count>=128 then return skip('duplicate / event limit') end
    self.visualized[identifier]=now
    if s.HitChance<=0 or (s.HitChance<100 and math.random(1,100)>s.HitChance) then return skip('hit chance') end
    local generation=self.visualizeGeneration or 0
    local remote,part=self.hitRemote,target.Part
    self.ShotStatus='Queued: '..pelletCount..' pellet(s)'
    task.delay(0,function()
        local ok,problem=pcall(function()
            if generation~=(self.visualizeGeneration or 0) or not self.alive or not s.Enabled or s.Universal
                or not self.engine.focused or Input:GetFocusedTextBox() or self.library:IsInteracting()
                or self.library:IsPointerOverUI() or (s.PauseMenu and self.library.open)
                or Players.LocalPlayer.Character~=character or tool.Parent~=character
                or character:FindFirstChildOfClass('Tool')~=tool then return skip('cancelled / unequipped / paused') end
            local fresh,reason=self.engine:Candidate(target.Player,workspace.CurrentCamera,p.Root,s,self.ray)
            if not fresh or fresh.Part~=part then return skip('target changed: '..tostring(reason)) end
            local hum=character:FindFirstChildOfClass('Humanoid')
            if not hum or hum.Health<=0 or character:FindFirstChildOfClass('ForceField') then return skip('local rig / ForceField') end
            local targetHum=target.Player.Character:FindFirstChildOfClass('Humanoid')
            if s.SkipDowned and self.melee:DownedState(target.Player,target.Player.Character,targetHum)
                and targetHum.Health<=15 then return skip('target downed') end
            local delta=part.Position-origin
            if delta.Magnitude<0.001 then return skip('zero direction') end
            for index=1,pelletCount do
                remote:FireServer(utf8.char(129480),tool,identifier,index,part,part.Position,delta.Unit)
                self:Count('visualize.reported')
            end
            self.ShotStatus='Sent '..pelletCount..' hit report(s); server damage unconfirmed'
            self:Log('info','shot.report',self.ShotStatus,{Shot=identifier,Target=target.Player.Name,Pellets=pelletCount})
            if s.ShowTracers then
                self:QueueTrace({Origin=origin,Original=finite(original) and original or delta,Sent=delta,End=part.Position,
                    Time=os.clock(),Redirected=true,Hit=false,Reason='Hit report sent; server damage unconfirmed'})
            end
        end)
        if not ok then
            self.ShotStatus='Error sending hit report: '..tostring(problem)
            self:Log('error','visualize.report',tostring(problem),nil,1)
        end
    end)
end
function Silent:InstallEffectsHook()
    if self.effectsHook then return true end
    local modules=Storage:FindFirstChild('NewModules')
    local client=modules and modules:FindFirstChild('Client')
    local services=client and client:FindFirstChild('Services')
    local module=services and services:FindFirstChild('Effects')
    if not module then return false,'Unavailable: gun Effects module not found' end
    local ok,api=pcall(require,module)
    if not ok or type(api)~='function' then return false,'Unavailable: unsupported Effects dispatcher' end
    local env=getgenv()
    env.LegitSilentEffectsHooks=env.LegitSilentEffectsHooks or {}
    local state=env.LegitSilentEffectsHooks[module]
    if state and state.Version~=2 then state.Owner=nil; state=nil end
    if not state then
        state={Version=2,Busy=setmetatable({},{__mode='k'})}; env.LegitSilentEffectsHooks[module]=state
        local original
        local wrap=type(newcclosure)=='function' and newcclosure or function(fn) return fn end
        local installed,problem=pcall(function()
            original=hookfunction(api,wrap(function(...)
                local owner=state.Owner
                if not owner or not owner.alive or not owner.config.Enabled or checkcaller() then return original(...) end
                return guardedCall(state,original,function(args) owner:Shoot(nil,args) end,...)
            end))
            assert(type(original)=='function','missing original Effects function')
        end)
        if not installed then env.LegitSilentEffectsHooks[module]=nil; return false,'Unavailable: Effects hook failed: '..tostring(problem) end
    end
    state.Owner=self; self.effectsHook=state
    self:Log('info','shoot.install','Shared gun direction list hook attached')
    return true
end
function Silent:Shoot(caller,args)
    if self.config.Universal then return end
    local p=self.gunContext
    if args[1]~='Shoot' then return end
    self:Count('shoot.seen')
    if args[4]~=true or not p or args[5]~=p.Tool then
        self:Count('shoot.skip.local gun scope'); return
    end
    local list=args[7]
    self:Log('info','shot.effects','Local gun shot',{Shot=args[3],Weapon=p.Tool.Name,Pellets=type(list)=='table' and #list or 0})
    if type(list)~='table' or #list<1 or #list>128 or table.isfrozen(list) then return end
    local originals,changed,reasons,replacements={},{},{},{}
    for i,direction in ipairs(list) do
        if not finite(direction) or direction.Magnitude<0.001 then return end
        originals[i]=direction
        local fake={nil,args[3],args[6],direction,self.ballistics and self.ballistics.Velocity or 1}
        fake[9]=self.ballistics and self.ballistics.Acceleration
        -- The local flag and equipped Tool identify this shot even when Effects
        -- runs from a shared module/coroutine rather than a child of the Tool.
        local sent,_,reason=self:AimLaunch(caller,'Fire',fake,true)
        replacements[i]=sent or direction; changed[i]=sent~=nil; reasons[i]=reason or 'redirected'
    end
    -- Preserve the list identity: Gun sends this same table after Effects returns.
    for i,direction in ipairs(replacements) do list[i]=direction end
    self.launches=self.launches or {}
    local now=os.clock()
    for id,launch in pairs(self.launches) do if now-launch.Time>2 then self.launches[id]=nil end end
    local count=0; for _ in pairs(self.launches) do count+=1 end
    if count>=16 then self.launches={} end
    if type(args[3])=='string' or type(args[3])=='number' then
        self.launches[args[3]]={Time=now,Tool=p.Tool,Originals=originals,Sent=replacements,Changed=changed,Reasons=reasons}
    end
    self:Count('shoot.prepared')
    self.DirectionStatus='Gun directions updated'
    self.ShotStatus='Gun directions updated before local/server launch'
end
function Silent:InstallProjectileHook()
    if self.projectileHook then return true end
    local module=self:FastCastModule()
    if not module then return false,'Unavailable: Criminality FastCastRedux not found' end
    local ok,api=pcall(require,module)
    if not ok or type(api)~='table' then return false,'Unavailable: cannot load FastCastRedux' end
    local methods={'Fire','FireWithBlacklist','FireWithWhitelist'}
    for _,method in ipairs(methods) do
        if type(api[method])~='function' then return false,'Unavailable: unsupported FastCast API' end
    end
    local env=getgenv()
    env.LegitSilentFastCastHooks=env.LegitSilentFastCastHooks or {}
    local state=env.LegitSilentFastCastHooks[module]
    if state and state.Version~=2 then state.Owner=nil; state=nil end
    if not state then state={Version=2,Methods={},Busy=setmetatable({},{__mode='k'})}; env.LegitSilentFastCastHooks[module]=state end
    -- hookfunction also catches references cached by the game's gun controller.
    for _,method in ipairs(methods) do
        if not state.Methods[method] then
            local original
            local wrap=type(newcclosure)=='function' and newcclosure or function(fn) return fn end
            local installed,problem=pcall(function()
                original=hookfunction(api[method],wrap(function(...)
                    local owner=state.Owner
                    if not owner or not owner.alive or not owner.config.Enabled or checkcaller() then return original(...) end
                    return guardedCall(state,original,function(args)
                        local direction,velocity=owner:Projectile(nil,method,args)
                        if direction then args[4],args[5]=direction,velocity end
                    end,...)
                end))
                assert(type(original)=='function','hookfunction did not return the original')
            end)
            if not installed then
                self:Log('error','projectile.install',tostring(problem),nil,5)
                return false,'Unavailable: FastCast hook failed ('..method..')'
            end
            state.Methods[method]=true
        end
    end
    state.Owner=self; self.projectileHook=state
    self:Log('info','projectile.install','FastCast observation hooks attached; launch steering is upstream')
    return true
end
function Silent:Step(now)
    -- End our previous Tool pulse before selecting/activating the next target.
    self:ReleaseAutoFire()
    local s=self.config
    if self.lastUniversal~=s.Universal then
        self:Equip(nil); self:Reset(); self.Backend=nil; self.lastUniversal=s.Universal
    end
    if self.raycastHook and not s.Enabled and self.raycastHook.SilentOwner==self then
        self.raycastHook.SilentOwner=nil
    end
    if not self.alive or not s.Enabled then self:Reset(); self:SetStatus('Disabled'); return end
    local unavailable=self:CapabilityProblem()
    if unavailable then self:Reset(); self:SetStatus(unavailable); return end
    if self.engine.ProjectileControl or not self.engine.focused or Input:GetFocusedTextBox() or self.library:IsInteracting()
        or self.library:IsPointerOverUI() or (s.PauseMenu and self.library.open) then
        self:Reset(); self:SetStatus('Paused by input / menu'); return
    end
    local character=Players.LocalPlayer.Character
    local humanoid=character and character:FindFirstChildOfClass('Humanoid')
    local root=character and character:FindFirstChild('HumanoidRootPart')
    local camera=workspace.CurrentCamera
    if not character or not humanoid or humanoid.Health<=0 or not root or not camera then
        self:Equip(nil); self:Reset(); self:SetStatus('Waiting for character / camera'); return
    end
    local tool=not s.Universal and character:FindFirstChildOfClass('Tool') or nil
    local values=tool and tool:FindFirstChild('Values')
    local ammo=values and (values:FindFirstChild('SERVER_Ammo') or values:FindFirstChild('Ammo') or values:FindFirstChild('StoredAmmo'))
    local eventBackend=not s.Universal and self:VisualizeObjects()~=nil
    -- Tool.Enabled commonly drops during the real weapon's fire cooldown.
    -- Visualize already identifies a real shot; ammo schema/cooldown must not
    -- clear its target context or cancel its delayed report.
    if not s.Universal and (not tool or self.melee:IsMeleeTool(tool)
        or (not eventBackend and (not tool.Enabled or not ammo))) then
        self:Equip(nil); self:Reset()
        self:SetStatus(tool and not self.melee:IsMeleeTool(tool) and not ammo
            and 'Unsupported gun: ammo values not found' or 'Equip an enabled gun')
        return
    end
    if s.Universal then
        self:Equip(nil)
        if not self.melee:InstallHook(true) then self:Reset(); self:SetStatus(self.melee.Status); return end
        self.raycastHook=self.melee.hook; self.raycastHook.SilentOwner=self
        self.Backend='Universal Raycast'
    else
        self:Equip(tool,eventBackend)
    end
    local visualize=not s.Universal and self:InstallVisualize()
    if visualize then self.Backend='Criminality Visualize' end
    -- Default gun mode never intercepts every per-segment workspace ray.
    -- Steering happens at launch; FastCast keeps its own collision traversal.
    -- Visualize and direction hooks are complementary in the reference.
    -- An event object existing does not mean it steers the real projectile.
    if not s.Universal and (not self.effectsHook or not self.projectileHook)
        and not self.installing and now>=(self.nextInstall or 0) then
        self.nextInstall=now+2
        if type(hookfunction)=='function' and type(checkcaller)=='function' then
            self.installing=true
            local effectsOK,effectsReason=self:InstallEffectsHook()
            local castOK,castReason=self:InstallProjectileHook()
            self.installing=false
            self.GunAdapterStatus=effectsOK and 'Effects attached' or (castOK and 'FastCast attached' or tostring(effectsReason or castReason))
        else self.GunAdapterStatus='Gun hooks unavailable' end
    end
    if not s.Universal then
        local adapters={}
        if visualize then table.insert(adapters,'Criminality Visualize') end
        if self.effectsHook then table.insert(adapters,'Gun directions')
        elseif self.projectileHook then table.insert(adapters,'FastCast') end
        if #adapters==0 then self:Reset(); self:SetStatus(self.GunAdapterStatus or 'No shot adapter'); return end
        self.Backend=table.concat(adapters,' + ')
    end
    self.ray.FilterDescendantsInstances={character,camera}
    local best,rejected,candidates=nil,{},{}
    -- Target scans and visibility checks stay outside the projectile hook.
    local ok,problem=pcall(function()
        for _,player in ipairs(Players:GetPlayers()) do
            local candidate,reason=self.engine:Candidate(player,camera,root,s,self.ray)
            if candidate then
                local targetChar=player.Character
                local targetHum=targetChar:FindFirstChildOfClass('Humanoid')
                local downed,flags=false,nil
                if s.SkipDowned then downed,flags=self.melee:DownedState(player,targetChar,targetHum) end
                if downed and targetHum.Health<=15 then candidate=nil; reason='downed/ragdoll <=15 HP'
                else candidate.Character=targetChar; candidate.Humanoid=targetHum; candidate.DownedFlags=flags; candidate.Downed=downed end
            end
            if candidate then table.insert(candidates,candidate) end
            if candidate and (not best or self.engine:TargetRank(player)<self.engine:TargetRank(best.Player)
                or (self.engine:TargetRank(player)==self.engine:TargetRank(best.Player) and (candidate.Score<best.Score
                    or (candidate.Score==best.Score and player.UserId<best.Player.UserId)))) then best=candidate end
            if reason and reason~='self' then rejected[reason]=(rejected[reason] or 0)+1 end
        end
    end)
    if not ok then error(problem) end
    if s.Full360 and s.CycleTargets and s.AutoFire then best=self:SelectCycleTarget(candidates)
    else self.cycleVisited=nil end
    self.gunContext={Target=best,Character=character,Humanoid=humanoid,Root=root,Tool=tool,
        Universal=s.Universal,CameraOrigin=camera.CFrame.Position}
    self.prepared=best and self.gunContext or nil
    self.circle.Position=camera.ViewportSize/2; self.circle.Radius=s.Radius
    self.circle.Color=s.FOVColor; self.circle.Transparency=s.FOVOpacity*self.engine:Opacity('Silent','FOVColor')
    self.circle.Visible=s.ShowFOV and not s.Full360
    local emptyStatus=s.Full360 and 'No target in range' or 'No target in FOV'
    self:SetStatus((best and ('Target: @'..best.Player.Name) or emptyStatus)..' ['..(self.Backend or 'waiting for shot')..(s.Full360 and ' / 360' or '')..']')
    self:AutoFireStep(now)
    if self.logger and self.logger.settings.Enabled and now-self.lastSummary>=2 then
        self.lastSummary=now
        self:Log('info','summary',self.Status,self.Counters)
        self:Log('info','filters','Rejected target evaluations',rejected)
    end
end
function Silent:SelectCycleTarget(candidates)
    if #candidates==0 then self.cycleVisited=nil; return nil end
    table.sort(candidates,function(a,b)
        if a.Distance~=b.Distance then return a.Distance<b.Distance end
        return a.Player.UserId<b.Player.UserId
    end)
    self.cycleVisited=self.cycleVisited or {}
    -- Remove departed/invalid targets rather than retaining player IDs indefinitely.
    local eligible={}
    for _,candidate in ipairs(candidates) do eligible[candidate.Player.UserId]=true end
    for id in pairs(self.cycleVisited) do if not eligible[id] then self.cycleVisited[id]=nil end end
    for _,candidate in ipairs(candidates) do
        if not self.cycleVisited[candidate.Player.UserId] then return candidate end
    end
    self.cycleVisited={}
    return candidates[1]
end
function Silent:ReleaseAutoFire()
    local tool=self.autoFireTool
    self.autoFireTool=nil
    if tool then
        local ok,problem=pcall(function() tool:Deactivate() end)
        if not ok then self:Log('error','autofire.release',tostring(problem),nil,1) end
    end
end
function Silent:AutoFireStep(now)
    local s,p=self.config,self.prepared
    if not self.alive or not s.Enabled or not s.AutoFire then self.AutoFireStatus='Disabled'; return end
    if not p or not p.Target or p.Target.Humanoid.Health<=0 or s.HitChance<=0 then
        self.AutoFireStatus='Waiting for target'; return
    end
    if not self.engine.focused or Input:GetFocusedTextBox() or self.library:IsInteracting()
        or self.library:IsPointerOverUI() or (s.PauseMenu and self.library.open) then
        self:ReleaseAutoFire(); self.AutoFireStatus='Paused by input / menu'; return
    end
    if now<(self.nextAutoFire or 0) then self.AutoFireStatus='Waiting for interval'; return end
    local tool=p.Universal and p.Character:FindFirstChildOfClass('Tool') or p.Tool
    local method=s.AutoFireMethod
    if method=='Auto' then method=tool and 'Tool' or 'Mouse' end
    if method=='Tool' and (not tool or tool.Parent~=p.Character or not tool.Enabled) then
        self.AutoFireStatus='Waiting for enabled Tool'; return
    end
    if method=='Mouse' and type(mouse1click)~='function' then
        self.AutoFireStatus='Unavailable: missing mouse1click'; return
    end
    self.nextAutoFire=now+math.max(0.05,s.AutoFireInterval)
    self:Count('autofire.attempted')
    local ok,problem=pcall(function()
        if method=='Tool' then self.autoFireTool=tool; tool:Activate()
        else mouse1click() end
    end)
    if not ok then
        self:ReleaseAutoFire(); self.AutoFireStatus='Activation failed'
        self:Log('error','autofire.activate',tostring(problem),nil,1)
    else
        if s.Full360 and s.CycleTargets and s.AutoFire then
            self.cycleVisited=self.cycleVisited or {}
            self.cycleVisited[p.Target.Player.UserId]=true
        end
        self.AutoFireStatus=method..': firing'
        self:Log('trace','autofire.activate','Activated input for selected target',
            {Method=method,Target=p.Target.Player.Name},0.5)
    end
end
function Silent:AimLaunch(caller,method,args,localShot)
    local function reject(reason) self:Count('shoot.skip.'..reason); return nil,nil,reason end
    local s,p=self.config,self.gunContext
    if not self.alive or not s.Enabled or s.Universal or not self.engine.focused or (s.PauseMenu and self.library.open) then return reject('paused') end
    if not p or p.Universal then return reject('no gun context') end
    local origin,direction,velocity=args[3],args[4],args[5]
    if not finite(origin) or not finite(direction) or direction.Magnitude<0.001 then return reject('invalid vector') end
    local speed=type(velocity)=='number' and velocity or (finite(velocity) and velocity.Magnitude)
    if not speed or speed~=speed or speed<=0 or speed>=math.huge then return reject('invalid velocity') end
    if Players.LocalPlayer.Character~=p.Character or p.Humanoid.Health<=0 or self.tool~=p.Tool
        or p.Tool.Parent~=p.Character then return reject('tool/rig') end
    if (origin-p.Root.Position).Magnitude>s.OriginRadius then return reject('distant origin') end
    if not localShot and not inside(caller,p.Tool) then return reject('caller mismatch') end
    local function skip(reason) return reject(reason) end
    local target=p.Target
    if not target then return skip('no target') end
    if target.Player.Parent~=Players or target.Player.Character~=target.Character
        or target.Humanoid.Health<=0 or target.Humanoid.Health<s.MinHealth or target.Part.Parent~=target.Character
        or (target.Part.Position-p.Root.Position).Magnitude>s.MaxDistance then return skip('target invalidated') end
    if s.SkipDowned and target.Humanoid.Health<=15 then
        if target.Downed or target.Humanoid.PlatformStand then return skip('downed/ragdoll') end
        for _,flag in ipairs(target.DownedFlags or {}) do if flag.Value then return skip('downed/ragdoll') end end
    end
    if s.HitChance<=0 or (s.HitChance<100 and math.random(1,100)>s.HitChance) then return skip('hit chance') end
    local delta=target.Position-origin
    if delta.Magnitude<0.001 then return skip('zero direction') end
    local unit=delta.Unit
    local acceleration=args[9]
    if finite(acceleration) and acceleration.Magnitude>0.001 then
        -- Solve |delta/t - acceleration*t/2| = speed for the shorter arc.
        local distance2=delta.Magnitude^2
        local b=speed^2+delta.X*acceleration.X+delta.Y*acceleration.Y+delta.Z*acceleration.Z
        local discriminant=b*b-acceleration.Magnitude^2*distance2
        if b<=0 or discriminant<0 then return skip('ballistic target unreachable') end
        local t2=2*distance2/(b+math.sqrt(discriminant))
        local launch=(delta-acceleration*(t2/2))/math.sqrt(t2)
        if not finite(launch) or launch.Magnitude<0.001 then return skip('invalid ballistic solution') end
        unit=launch.Unit
    end
    local sent=unit*direction.Magnitude
    self:Count('shoot.redirected')
    self:Log('trace','shoot.direction','Shared local/server launch direction prepared',
        {Method=method,Speed=speed,Range=direction.Magnitude,Target=target.Player.Name},0.5)
    return sent,type(velocity)=='number' and velocity or unit*speed
end
function Silent:Projectile(caller,method,args)
    if self.config.Universal then return end
    -- Observation only. The gun's shared direction list was already changed upstream.
    self:Count('projectile.seen')
    local launch=self.launches and self.launches[args[2]]
    if launch and (os.clock()-launch.Time>2 or launch.Tool~=self.tool) then launch=nil end
    if not launch then
        local p=self.gunContext
        local localShot=false
        if p and args[8]==true then
            if method=='Fire' then localShot=args[7]==p.Character
            elseif method=='FireWithBlacklist' and type(args[6])=='table' then
                for _,excluded in ipairs(args[6]) do if excluded==p.Character then localShot=true; break end end
            end
        end
        if not localShot then self:Count('projectile.skip.foreign shooter'); return end
        local direction,velocity,reason=self:AimLaunch(caller,method,args,true)
        if direction then self.DirectionStatus='FastCast launch redirected' end
        self.Backend='FastCast launch fallback'
        self:Count('projectile.fallback')
        if self.config.ShowTracers and finite(args[3]) and finite(args[4]) then
            self:TrackProjectile(args,method,{Origin=args[3],Original=args[4],Sent=direction or args[4],
                Time=os.clock(),Redirected=direction~=nil,Reason=reason or 'redirected at FastCast'})
        end
        return direction,velocity
    end
    local direction=args[4]
    if not finite(direction) or direction.Magnitude<0.001 then return end
    local index
    for i,sent in ipairs(launch.Sent) do
        if (sent.Unit-direction.Unit).Magnitude<0.001 then index=i; break end
    end
    if not index then self:Count('projectile.skip.direction mismatch'); return end
    local now=os.clock()
    if not self.config.ShowTracers or now<(self.nextTrace or 0) then return end
    self.nextTrace=now+0.05
    self:TrackProjectile(args,method,{Origin=args[3],Original=launch.Originals[index].Unit*direction.Magnitude,
        Sent=direction,Time=now,Redirected=launch.Changed[index],Reason=launch.Reasons[index]})
end
-- Explicit Universal mode only: preserve the exact ray length and original collision params.
-- Never extend FastCast segments or replace collision filters inside its traversal.
function Silent:Redirect(_,origin,direction)
    local s,p=self.config,self.gunContext
    if not self.alive or not s.Enabled or not s.Universal or not p or not p.Universal
        or self.engine.ProjectileControl or not self.engine.focused or (s.PauseMenu and self.library.open) then return end
    if not finite(origin) or not finite(direction) or direction.Magnitude<0.001 then return end
    if Players.LocalPlayer.Character~=p.Character or p.Humanoid.Health<=0 then return end
    if not s.Universal and (self.tool~=p.Tool or not p.Tool or p.Tool.Parent~=p.Character) then return end
    if (origin-p.Root.Position).Magnitude>s.OriginRadius and (origin-p.CameraOrigin).Magnitude>s.OriginRadius then return end
    local target=p.Target
    local sent,reason=nil,'no target'
    if target and target.Player.Parent==Players and target.Player.Character==target.Character
        and target.Humanoid.Health>0 and target.Humanoid.Health>=s.MinHealth
        and target.Part.Parent==target.Character and (target.Part.Position-p.Root.Position).Magnitude<=s.MaxDistance then
        local downed=false
        if s.SkipDowned and target.Humanoid.Health<=15 then
            downed=target.Downed or target.Humanoid.PlatformStand
            for _,flag in ipairs(target.DownedFlags or {}) do if flag.Value then downed=true end end
        end
        local delta=target.Position-origin
        reason='range / downed / hit chance'
        if not downed and delta.Magnitude>0.001 and delta.Magnitude<=direction.Magnitude
            and s.HitChance>0 and (s.HitChance>=100 or math.random(1,100)<=s.HitChance) then
            sent=delta.Unit*direction.Magnitude; reason='redirected'
            self.DirectionStatus='Weapon Raycast redirected'
            self:Count('ray.redirected')
        end
    end
    local trace
    local now=os.clock()
    if s.ShowTracers and now>=(self.nextUniversalTrace or 0) then
        self.nextUniversalTrace=now+0.05
        trace={Origin=origin,Original=direction,Sent=sent or direction,Time=now,Redirected=sent~=nil,Reason=reason}
    end
    return sent,trace
end
function Silent:ObserveHit() end -- The shared dispatcher records the actual result below.
function Silent:RecordTrace(trace,result)
    local hit=(typeof(result)=='RaycastResult' or type(result)=='table') and result or nil
    trace.End=hit and finite(hit.Position) and hit.Position or trace.Origin+trace.Sent
    trace.Hit=hit and hit.Instance~=nil or false
    self:QueueTrace(trace)
end
function Silent:QueueTrace(trace)
    if trace.Queued then return end
    trace.Queued=true
    if #self.traceQueue>=16 then table.remove(self.traceQueue,1) end
    table.insert(self.traceQueue,trace)
end
function Silent:TrackProjectile(args,method,trace)
    local caster=args[1]
    local bullet=args[method=='Fire' and 6 or 7]
    if not caster or not bullet then return end
    local found=false
    for _,entry in ipairs(self.casters) do if entry.Caster==caster then found=true; break end end
    if not found then
        if #self.casters>=16 then
            local old=table.remove(self.casters,1)
            for _,connection in ipairs(old.Connections) do connection:Disconnect() end
        end
        local connections={}
        local function connect(signal,callback)
            if signal and type(signal.Connect)=='function' then table.insert(connections,signal:Connect(callback)) end
        end
        connect(caster.LengthChanged,function(_,from,unit,length,_,projectile)
            local shot=self.projectiles[projectile]
            if not shot or os.clock()-(shot.Created or shot.Time)>15 then return end
            if finite(from) and finite(unit) and type(length)=='number' and length==length and length>=0 and length<math.huge then
                shot.End=from+unit*length; shot.Time=os.clock(); self:QueueTrace(shot)
            end
        end)
        connect(caster.RayHit,function(_,_,_,hit,position,_,_,_,_,projectile)
            local shot=self.projectiles[projectile]
            if not shot then return end
            self.projectiles[projectile]=nil
            if finite(position) then shot.End=position; shot.Time=os.clock(); shot.Hit=hit~=nil; self:QueueTrace(shot) end
            self:Count(hit and 'projectile.clientHit' or 'projectile.rangeEnd')
            self:Log('trace','projectile.result','FastCast client result; not server damage confirmation',
                {Hit=hit~=nil,Redirected=shot.Redirected},0.5)
        end)
        table.insert(self.casters,{Caster=caster,Connections=connections})
    end
    -- Bound retained projectile records independently of missing/late hit signals.
    local count,oldest,oldestTime=0,nil,math.huge
    for projectile,shot in pairs(self.projectiles) do
        if os.clock()-(shot.Created or shot.Time)>15 then self.projectiles[projectile]=nil
        else
            count+=1
            if shot.Time<oldestTime then oldest,oldestTime=projectile,shot.Time end
        end
    end
    if count>=16 then self.projectiles[oldest]=nil end
    trace.Created=trace.Time
    self.projectiles[bullet]=trace
end
local function screenPoint(camera,position)
    local p=camera:WorldToViewportPoint(position)
    local size=camera.ViewportSize
    if p.Z<=0.01 or p.X<0 or p.Y<0 or p.X>size.X or p.Y>size.Y then return end
    return Vector2.new(p.X,p.Y)
end
function Silent:NewTraceSlot()
    local function part(name)
        local object=Instance.new('Part')
        object.Name=name; object.Anchored=true
        object.CanCollide=false; object.CanTouch=false; object.CanQuery=false
        object.CastShadow=false; object.Transparency=1
        object.Size=Vector3.new(0.2,0.2,0.2); object.Position=Vector3.zero
        return object
    end
    local root=part('LegitShotTrace'); root.Parent=workspace
    local from=Instance.new('Attachment'); from.Parent=root
    local to=Instance.new('Attachment'); to.Parent=root
    local originalTo=Instance.new('Attachment'); originalTo.Parent=root
    local function beam(endpoint)
        local object=Instance.new('Beam')
        object.Attachment0=from; object.Attachment1=endpoint
        object.FaceCamera=true; object.LightEmission=1; object.LightInfluence=0
        object.Segments=1; object.Enabled=false; object.Parent=root
        return object
    end
    local hit=part('ClientHit'); hit.Shape=Enum.PartType.Ball
    hit.Material=Enum.Material.Neon; hit.Parent=root
    return {Root=root,From=from,To=to,OriginalTo=originalTo,Sent=beam(to),Original=beam(originalTo),Hit=hit}
end
function Silent:Render(now)
    local s,camera=self.config,workspace.CurrentCamera
    if not self.alive or not s.Enabled or not camera or not self.engine.focused
        or (s.PauseMenu and self.library.open) then return end
    local cyan,orange=Color3.fromRGB(70,235,255),Color3.fromRGB(255,155,65)
    local function drawing(kind)
        local object=self.engine.Drawing.new(kind); object.Visible=false; object.ZIndex=35
        return object
    end
    if not s.ShowTracers then self.traceQueue={}; self.shots={}; self.projectiles={} end
    for _,shot in ipairs(self.traceQueue) do table.insert(self.shots,shot) end
    self.traceQueue={}
    for index=#self.shots,1,-1 do
        if now-self.shots[index].Time> s.TraceDuration then table.remove(self.shots,index) end
    end
    while #self.shots>16 do table.remove(self.shots,1) end
    for index,shot in ipairs(self.shots) do
        local slot=self.tracePool[index]
        if not slot then slot=self:NewTraceSlot(); self.tracePool[index]=slot end
        local color=shot.Redirected and cyan or orange
        local alpha=math.clamp(1-(now-shot.Time)/s.TraceDuration,0,1)
        slot.From.Position=shot.Origin; slot.To.Position=shot.End
        slot.Sent.Color=ColorSequence.new(color)
        slot.Sent.Width0=s.TraceWidth; slot.Sent.Width1=s.TraceWidth
        slot.Sent.Transparency=NumberSequence.new(1-alpha)
        slot.Sent.Enabled=true
        slot.Original.Enabled=s.ShowOriginalRay
        if s.ShowOriginalRay then
            slot.OriginalTo.Position=shot.Origin+shot.Original.Unit*(shot.End-shot.Origin).Magnitude
            slot.Original.Color=ColorSequence.new(Color3.fromRGB(170,170,180))
            slot.Original.Width0=s.TraceWidth/2; slot.Original.Width1=s.TraceWidth/2
            slot.Original.Transparency=NumberSequence.new(1-alpha*0.5)
        end
        slot.Hit.Position=shot.End; slot.Hit.Color=color
        slot.Hit.Transparency=shot.Hit and 1-alpha or 1
    end
    for index=#self.shots+1,#self.tracePool do
        local slot=self.tracePool[index]
        slot.Sent.Enabled=false; slot.Original.Enabled=false; slot.Hit.Transparency=1
    end
    if s.ShowTargetGuide then
        if not self.targetDot then
            self.targetDot=drawing('Circle'); self.targetDot.Radius=6; self.targetDot.Filled=false; self.targetDot.Thickness=2
            self.targetLabel=drawing('Text'); self.targetLabel.Size=13; self.targetLabel.Outline=true
        end
        local target=self.prepared and self.prepared.Target
        local point=target and screenPoint(camera,target.Position)
        local gold=Color3.fromRGB(255,215,90)
        self.targetDot.Visible=point~=nil
        if point then self.targetDot.Position=point; self.targetDot.Color=gold end
        self.targetLabel.Visible=true; self.targetLabel.Color=gold
        self.targetLabel.Position=point and point+Vector2.new(9,-18) or camera.ViewportSize/2+Vector2.new(0,s.Radius+16)
        self.targetLabel.Text=point and 'SA target (guide)' or ('SA: '..self.Status)
    elseif self.targetDot then self.targetDot.Visible=false; self.targetLabel.Visible=false end
end
function Silent:Start()
    local nextUpdate=0
    self.connection=RunService.Heartbeat:Connect(function()
        local now=os.clock(); if now<nextUpdate then return end; nextUpdate=now+1/30
        local ok,problem=xpcall(function() self:Step(now); self:Render(now) end,debug.traceback)
        if not ok then self:Reset(); self:SetStatus('Error in silent update'); self:Log('error','heartbeat',problem,nil,1) end
    end)
end
function Silent:Destroy()
    if not self.alive then return end
    self.alive=false; self:Reset(); self.tool,self.ballistics=nil,nil
    if self.connection then self.connection:Disconnect() end
    if self.visualizeConnection then self.visualizeConnection:Disconnect(); self.visualizeConnection=nil end
    if self.projectileHook and self.projectileHook.Owner==self then self.projectileHook.Owner=nil end
    if self.effectsHook and self.effectsHook.Owner==self then self.effectsHook.Owner=nil end
    if self.raycastHook and self.raycastHook.SilentOwner==self then self.raycastHook.SilentOwner=nil end
    for _,slot in ipairs(self.tracePool) do slot.Root:Destroy() end
    if self.targetDot then self.targetDot:Remove(); self.targetLabel:Remove() end
    self.tracePool={}; self.traceQueue={}; self.shots={}
    self.circle:Remove()
end
return Silent
