-- Camera-independent steering of scoped, real gun rays. No synthetic hit results/remotes.
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
function Silent.new(config,engine,library,melee)
    local self=setmetatable({config=config,engine=engine,library=library,melee=melee,logger=engine.Logger,
        alive=true,Counters={},Status='Disabled',connections={},fireUntil=0,lastSummary=0,
        traceQueue={},shots={},tracePool={}},Silent)
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
    self.prepared,self.gunContext=nil,nil; self.circle.Visible=false
    self.traceQueue={}; self.shots={}
    for _,slot in ipairs(self.tracePool) do
        for _,object in pairs(slot) do if object.Visible then object.Visible=false end end
    end
    if self.targetDot then self.targetDot.Visible=false; self.targetLabel.Visible=false end
end
function Silent:Equip(tool)
    if self.tool==tool then return end
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections={}; self.tool=tool; self.firing=false; self.fireUntil=0; self:Reset()
    if tool then
        table.insert(self.connections,tool.Activated:Connect(function() self.firing=true; self.fireUntil=os.clock()+0.25 end))
        table.insert(self.connections,tool.Deactivated:Connect(function() self.firing=false; self.fireUntil=0 end))
    end
end
function Silent:SharedCallers()
    local modules=Storage:FindFirstChild('NewModules')
    local shared=modules and modules:FindFirstChild('Shared')
    local services=shared and shared:FindFirstChild('Services')
    local callers={}
    if services then
        for _,name in ipairs({'RayHandler','FastCastRedux'}) do
            local script=services:FindFirstChild(name)
            if script and script:IsA('ModuleScript') then callers[script]=true end
        end
    end
    return callers
end
function Silent:Step(now)
    local s=self.config
    if not self.alive or not s.Enabled then self:Reset(); self:SetStatus('Disabled'); return end
    local unavailable=self.melee:CapabilityProblem()
    if unavailable then self:Reset(); self:SetStatus(unavailable); return end
    if not self.engine.focused or Input:GetFocusedTextBox() or self.library:IsInteracting()
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
    local tool=character:FindFirstChildOfClass('Tool')
    local values=tool and tool:FindFirstChild('Values')
    local ammo=values and (values:FindFirstChild('SERVER_Ammo') or values:FindFirstChild('Ammo') or values:FindFirstChild('StoredAmmo'))
    if not tool or not tool.Enabled or self.melee:IsMeleeTool(tool) or not ammo then
        self:Equip(nil); self:Reset()
        self:SetStatus(tool and not self.melee:IsMeleeTool(tool) and not ammo
            and 'Unsupported gun: ammo values not found' or 'Equip an enabled gun')
        return
    end
    self:Equip(tool)
    if not self.hook then
        if not self.melee:InstallHook() then self:Reset(); self:SetStatus(self.melee.Status); return end
        self.hook=self.melee.hook; self.hook.SilentOwner=self
    end
    self.ray.FilterDescendantsInstances={character,camera}
    local best,rejected=nil,{}
    -- Engine target selection runs outside __namecall, with independent settings.
    local ok,problem=pcall(function()
        for _,player in ipairs(Players:GetPlayers()) do
            local candidate,reason=self.engine:Candidate(player,camera,root,s,self.ray)
            if candidate then
                local targetChar=player.Character
                local targetHum=targetChar:FindFirstChildOfClass('Humanoid')
                local downed,flags=false,nil
                if s.SkipDowned then downed,flags=self.melee:DownedState(player,targetChar,targetHum) end
                if downed then candidate=nil; reason='downed/ragdoll'
                else candidate.Character=targetChar; candidate.Humanoid=targetHum; candidate.DownedFlags=flags end
            end
            if candidate and (not best or self.engine:TargetRank(player)<self.engine:TargetRank(best.Player)
                or (self.engine:TargetRank(player)==self.engine:TargetRank(best.Player) and (candidate.Score<best.Score
                    or (candidate.Score==best.Score and player.UserId<best.Player.UserId)))) then best=candidate end
            if reason and reason~='self' then rejected[reason]=(rejected[reason] or 0)+1 end
        end
    end)
    if not ok then error(problem) end
    self.gunContext={Target=best,Character=character,Humanoid=humanoid,Root=root,Tool=tool,
        Shared=self:SharedCallers(),FireHeld=Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)}
    self.prepared=best and self.gunContext or nil
    self.circle.Position=camera.ViewportSize/2; self.circle.Radius=s.Radius
    self.circle.Color=s.FOVColor; self.circle.Transparency=s.FOVOpacity*self.engine:Opacity('Silent','FOVColor')
    self.circle.Visible=s.ShowFOV
    self:SetStatus(best and ('Target: @'..best.Player.Name) or 'No target in FOV')
    if self.logger and self.logger.settings.Enabled and now-self.lastSummary>=2 then
        self.lastSummary=now
        self:Log('info','summary',self.Status,self.Counters)
        self:Log('info','filters','Rejected target evaluations',rejected)
    end
end
function Silent:Redirect(caller,origin,direction,params)
    -- Properties and cached Lua data only: no Instance methods inside __namecall.
    local function reject(reason) self:Count('ray.skip.'..reason); return nil end
    local s,p=self.config,self.gunContext
    if not self.alive or not s.Enabled or not self.engine.focused or (s.PauseMenu and self.library.open) then return reject('paused') end
    if not p then return reject('no gun context') end
    if not finite(origin) or not finite(direction) or direction.Magnitude<0.001 then return reject('invalid vector') end
    if Players.LocalPlayer.Character~=p.Character or p.Humanoid.Health<=0 or self.tool~=p.Tool
        or p.Tool.Parent~=p.Character or not p.Tool.Enabled then return reject('tool/rig') end
    if (origin-p.Root.Position).Magnitude>s.OriginRadius then return reject('distant origin') end
    if not inside(caller,p.Tool) then
        if not p.Shared[caller] then return reject('caller mismatch') end
        -- Shared bullet simulation also handles other players; require local shooter exclusions.
        if not params or params.FilterType~=Enum.RaycastFilterType.Exclude then return reject('shared filter') end
        local localFilter=false
        for _,excluded in ipairs(params.FilterDescendantsInstances or {}) do
            if excluded==p.Character or excluded==p.Tool then localFilter=true; break end
        end
        if not localFilter then return reject('shared filter') end
    end
    -- Sampling only stores Lua/vector data; no GUI or Instance methods in the hook.
    local trace
    local now=os.clock()
    if s.ShowTracers and now>=(self.nextTrace or 0) then
        self.nextTrace=now+0.05
        trace={Origin=origin,Original=direction,Sent=direction,Time=now,Redirected=false}
    end
    local function skip(reason)
        self:Count('ray.skip.'..reason)
        if trace then trace.Reason=reason end
        return nil,trace
    end
    if not (p.FireHeld or self.firing or os.clock()<self.fireUntil) then return skip('not firing') end
    local target=p.Target
    if not target then return skip('no target') end
    if target.Player.Parent~=Players or target.Player.Character~=target.Character
        or target.Humanoid.Health<=0 or target.Humanoid.Health<s.MinHealth or target.Part.Parent~=target.Character
        or (target.Part.Position-p.Root.Position).Magnitude>s.MaxDistance then return skip('target invalidated') end
    if s.SkipDowned then
        if target.Humanoid.PlatformStand then return skip('downed/ragdoll') end
        for _,flag in ipairs(target.DownedFlags or {}) do if flag.Value then return skip('downed/ragdoll') end end
    end
    if s.HitChance<=0 or (s.HitChance<100 and math.random(1,100)>s.HitChance) then return skip('hit chance') end
    local delta=target.Position-origin
    if delta.Magnitude<0.001 then return skip('zero direction') end
    local sent=delta.Unit*direction.Magnitude
    if trace then trace.Sent=sent; trace.Redirected=true; trace.Reason='redirected' end
    return sent,trace
end
function Silent:RecordTrace(trace,result)
    -- Called after the original Raycast. Reading result properties preserves namecall context.
    local resultType=typeof(result)
    local position=(resultType=='RaycastResult' or type(result)=='table') and result.Position
    trace.Hit=finite(position)
    trace.End=trace.Hit and position or trace.Origin+trace.Sent
    if #self.traceQueue>=16 then table.remove(self.traceQueue,1) end
    table.insert(self.traceQueue,trace)
    if self.logger and self.logger.settings.Enabled then
        local function vector(v) return string.format('%.2f,%.2f,%.2f',v.X,v.Y,v.Z) end
        self:Log('trace','shot',trace.Reason,{Origin=vector(trace.Origin),Direction=vector(trace.Sent),
            End=vector(trace.End),Hit=trace.Hit},0.5)
    end
end
function Silent:ObserveHit(result)
    self:Count('ray.redirected')
    if self.logger and self.logger.settings.Enabled and self.logger.settings.CaptureRays then
        self:Log('trace','ray.result','Client ray result; not server damage confirmation',
            {Hit=(typeof(result)=='RaycastResult' or type(result)=='table') and result.Instance~=nil or false},0.5)
    end
end
local function screenPoint(camera,position)
    local p=camera:WorldToViewportPoint(position)
    local size=camera.ViewportSize
    if p.Z<=0.01 or p.X<0 or p.Y<0 or p.X>size.X or p.Y>size.Y then return end
    return Vector2.new(p.X,p.Y)
end
local function screenSegment(camera,from,to)
    local a=camera:WorldToViewportPoint(from)
    local b=camera:WorldToViewportPoint(to)
    if a.Z<=0.01 and b.Z<=0.01 then return end
    if a.Z<=0.01 then
        from=from+(to-from)*((0.02-a.Z)/(b.Z-a.Z))
        a=camera:WorldToViewportPoint(from)
    elseif b.Z<=0.01 then
        to=from+(to-from)*((0.02-a.Z)/(b.Z-a.Z))
        b=camera:WorldToViewportPoint(to)
    end
    -- Clip to the viewport so long/offscreen rays never create enormous GUI frames.
    local dx,dy=b.X-a.X,b.Y-a.Y
    local low,high=0,1
    for _,edge in ipairs({{-dx,a.X},{dx,camera.ViewportSize.X-a.X},{-dy,a.Y},{dy,camera.ViewportSize.Y-a.Y}}) do
        local p,q=edge[1],edge[2]
        if math.abs(p)<0.000001 then if q<0 then return end
        else
            local t=q/p
            if p<0 then low=math.max(low,t) else high=math.min(high,t) end
            if low>high then return end
        end
    end
    return Vector2.new(a.X+dx*low,a.Y+dy*low),Vector2.new(a.X+dx*high,a.Y+dy*high)
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
    if not s.ShowTracers then self.traceQueue={}; self.shots={} end
    for _,shot in ipairs(self.traceQueue) do table.insert(self.shots,shot) end
    self.traceQueue={}
    for index=#self.shots,1,-1 do
        if now-self.shots[index].Time> s.TraceDuration then table.remove(self.shots,index) end
    end
    while #self.shots>16 do table.remove(self.shots,1) end
    for index,shot in ipairs(self.shots) do
        local slot=self.tracePool[index]
        if not slot then
            slot={Original=drawing('Line'),Sent=drawing('Line'),Dot=drawing('Circle'),Label=drawing('Text')}
            slot.Dot.Radius=4; slot.Dot.Filled=true; slot.Label.Size=12; slot.Label.Outline=true
            self.tracePool[index]=slot
        end
        local color=shot.Redirected and cyan or orange
        local alpha=math.clamp(1-(now-shot.Time)/s.TraceDuration,0,1)
        local from,to=screenSegment(camera,shot.Origin,shot.End)
        slot.Sent.Visible=from~=nil
        if from then
            slot.Sent.From,slot.Sent.To=from,to; slot.Sent.Color=color
            slot.Sent.Thickness=s.TraceThickness; slot.Sent.Transparency=alpha
        end
        local originalFrom,originalTo
        if s.ShowOriginalRay then originalFrom,originalTo=screenSegment(camera,shot.Origin,shot.Origin+shot.Original) end
        slot.Original.Visible=originalFrom~=nil
        if originalFrom then
            slot.Original.From,slot.Original.To=originalFrom,originalTo
            slot.Original.Color=Color3.fromRGB(170,170,180); slot.Original.Thickness=1; slot.Original.Transparency=alpha*0.5
        end
        local endpoint=screenPoint(camera,shot.End)
        slot.Dot.Visible=endpoint~=nil; slot.Label.Visible=endpoint~=nil
        if endpoint then
            slot.Dot.Position=endpoint; slot.Dot.Color=color; slot.Dot.Transparency=alpha
            slot.Label.Position=endpoint+Vector2.new(7,5); slot.Label.Color=color; slot.Label.Transparency=alpha
            slot.Label.Text=(shot.Redirected and 'SA' or ('PASS: '..shot.Reason))..(shot.Hit and ' / client hit' or ' / ray end')
        end
    end
    for index=#self.shots+1,#self.tracePool do
        for _,object in pairs(self.tracePool[index]) do if object.Visible then object.Visible=false end end
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
    self.alive=false; self:Equip(nil)
    if self.connection then self.connection:Disconnect() end
    if self.hook and self.hook.SilentOwner==self then self.hook.SilentOwner=nil end
    for _,slot in ipairs(self.tracePool) do for _,object in pairs(slot) do object:Remove() end end
    if self.targetDot then self.targetDot:Remove(); self.targetLabel:Remove() end
    self.tracePool={}; self.traceQueue={}; self.shots={}
    self.circle:Remove()
end
return Silent
