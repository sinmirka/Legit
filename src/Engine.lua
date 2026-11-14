-- Rendering and camera targeting. UI is owned by Obsidian via src/ObsidianUI.lua.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Input = game:GetService('UserInputService')
local Http = game:GetService('HttpService')
local Engine = {}
Engine.__index = Engine

local skeleton = {
    {'Head','UpperTorso'}, {'UpperTorso','LowerTorso'},
    {'UpperTorso','LeftUpperArm'}, {'LeftUpperArm','LeftLowerArm'}, {'LeftLowerArm','LeftHand'},
    {'UpperTorso','RightUpperArm'}, {'RightUpperArm','RightLowerArm'}, {'RightLowerArm','RightHand'},
    {'LowerTorso','LeftUpperLeg'}, {'LeftUpperLeg','LeftLowerLeg'}, {'LeftLowerLeg','LeftFoot'},
    {'LowerTorso','RightUpperLeg'}, {'RightUpperLeg','RightLowerLeg'}, {'RightLowerLeg','RightFoot'},
    {'Head','Torso'}, {'Torso','Left Arm'}, {'Torso','Right Arm'}, {'Torso','Left Leg'}, {'Torso','Right Leg'},
}
local function drawing(factory, class, props)
    local object = factory.new(class)
    object.Visible = false
    for key, value in pairs(props or {}) do object[key] = value end
    return object
end
local function removeDrawing(object)
    local removed=pcall(function() object:Remove() end)
    if not removed then
        removed=pcall(function() object:Destroy() end)
        if not removed then pcall(function() object.Visible=false end) end
    end
end
local function characterOf(player)
    local character = player.Character
    if not character or not character:IsDescendantOf(workspace) then return nil end
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local root = character:FindFirstChild('HumanoidRootPart') or (humanoid and humanoid.RootPart) or character.PrimaryPart or character:FindFirstChild('Torso')
    if not humanoid or humanoid.Health <= 0 or not root or not root:IsA('BasePart') then return nil end
    return character, humanoid, root
end
local function sameTeam(a, b)
    return not a.Neutral and not b.Neutral and a.Team ~= nil and a.Team == b.Team
end
local function point(camera, position)
    local p, onScreen = camera:WorldToViewportPoint(position)
    return Vector2.new(p.X, p.Y), onScreen and p.Z > 0
end
function Engine.new(config, library, renderer)
    local self = setmetatable({}, Engine)
    self.config, self.library = config, library
    self.Drawing=renderer or Drawing
    self.player = Players.LocalPlayer
    self.records, self.connections, self.friends = {}, {}, {}
    self.playerModes={}
    self.held, self.toggled, self.focused = false, false, true
    self.alive, self.target = true, nil
    self.pending, self.pendingSince, self.lastSwitch = nil, 0, -math.huge
    self.renderName = 'Legit_' .. Http:GenerateGUID(false)
    self.ray = RaycastParams.new()
    self.ray.FilterType = Enum.RaycastFilterType.Exclude
    self.ray.IgnoreWater = true
    self.folder = Instance.new('Folder')
    self.folder.Name = self.renderName
    self.folder.Parent = workspace
    self.fov = drawing(self.Drawing, 'Circle', {Filled=false, NumSides=96, Thickness=1, ZIndex=30})
    self.deadzone = drawing(self.Drawing, 'Circle', {Filled=false, NumSides=64, Thickness=1, ZIndex=30})
    self.aimLine = drawing(self.Drawing, 'Line', {Thickness=1, ZIndex=30})
    return self
end
function Engine:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.connections, connection)
    return connection
end
function Engine:Opacity(group,key)
    return self.config.Alpha[group..'_'..key] or 1
end
function Engine:TrackFriend(other)
    if other == self.player then return end
    task.spawn(function()
        local ok, result = pcall(self.player.IsFriendsWith, self.player, other.UserId)
        if self.alive and other.Parent == Players then self.friends[other] = ok and result or false end
    end)
end
function Engine:Allowed(other, settings)
    if other == self.player or other.Parent ~= Players then return false end
    if self.playerModes[other.UserId]=='Friend' and (settings==self.config.Aim or settings==self.config.Melee) then return false end
    if settings.TeamCheck and sameTeam(self.player, other) then return false end
    if settings.SkipFriends and self.friends[other] then return false end
    return true
end
function Engine:TargetRank(other) return self.playerModes[other.UserId]=='Enemy' and 0 or 1 end
function Engine:Visible(character, position, camera)
    local delta = position - camera.CFrame.Position
    if delta.Magnitude < 0.01 then return true end
    local hit = workspace:Raycast(camera.CFrame.Position, delta, self.ray)
    return not hit or hit.Instance:IsDescendantOf(character)
end
function Engine:Candidate(other, camera, localRoot)
    local a = self.config.Aim
    if other==self.player then return nil,'self' end
    if a.TeamCheck and sameTeam(self.player,other) then return nil,'team' end
    if not self:Allowed(other, a) then return nil,'friend' end
    local character, humanoid, root = characterOf(other)
    if not character or humanoid.Health < a.MinHealth then return nil,'rig/health' end
    if a.SkipForceField and character:FindFirstChildOfClass('ForceField') then return nil,'ForceField' end
    local distance = (root.Position - localRoot.Position).Magnitude
    if distance > a.MaxDistance then return nil,'distance' end
    local part = character:FindFirstChild(a.Part)
    if not part then
        local r6={UpperTorso='Torso',LowerTorso='Torso',LeftUpperArm='Left Arm',RightUpperArm='Right Arm',
            LeftUpperLeg='Left Leg',RightUpperLeg='Right Leg'}
        if r6[a.Part] then part=character:FindFirstChild(r6[a.Part]) end
    end
    if not part or not part:IsA('BasePart') then return nil,'body part' end
    local position = part.Position + Vector3.new(a.OffsetX, a.OffsetY, a.OffsetZ)
    if a.Prediction then position = position + root.AssemblyLinearVelocity * a.LeadTime end
    local screen, onScreen = point(camera, position)
    if not onScreen then return nil,'offscreen' end
    local pixels = (screen - camera.ViewportSize/2).Magnitude
    if pixels > a.Radius then return nil,'FOV' end
    if a.WallCheck and not self:Visible(character, part.Position, camera) then return nil,'wall' end
    local score = pixels
    if a.Priority == 'Distance' then score = distance end
    if a.Priority == 'Lowest health' then score = humanoid.Health end
    return {Player=other, Part=part, Position=position, Screen=screen, Pixels=pixels, Score=score}
end
function Engine:ResetTarget()
    self.target, self.pending = nil, nil
    self.aimLine.Visible = false
end
function Engine:Choose(camera, root, now)
    local a = self.config.Aim
    local current = self.target and self:Candidate(self.target, camera, root)
    if current and (a.Sticky or now - self.lastSwitch < a.SwitchDelay) then
        self.pending = nil
        return current
    end
    local best
    self.Rejected={}
    for _, other in ipairs(Players:GetPlayers()) do
        local candidate,reason = self:Candidate(other, camera, root)
        if not candidate and reason~='self' then self.Rejected[reason or 'other']=(self.Rejected[reason or 'other'] or 0)+1 end
        if candidate and (not best or self:TargetRank(other)<self:TargetRank(best.Player)
            or (self:TargetRank(other)==self:TargetRank(best.Player) and (candidate.Score < best.Score
                or (candidate.Score == best.Score and other.UserId < best.Player.UserId)))) then
            best = candidate
        end
    end
    if best and best.Player == self.target then self.pending = nil; return best end
    if not best then self:ResetTarget(); return nil end
    if self.pending ~= best.Player then self.pending, self.pendingSince = best.Player, now end
    if now - self.pendingSince < a.AcquireDelay then
        if not current then self.target = nil end
        return current
    end
    self.target, self.lastSwitch, self.pending = best.Player, now, nil
    return best
end
function Engine:SetStatus(value)
    self.Status=value
    if self.library.SetStatus then self.library:SetStatus(value) end
end
function Engine:PointerBlocked()
    return (self.library.IsPointerOverUI and self.library:IsPointerOverUI()) or (self.library.IsInteracting and self.library:IsInteracting()) or false
end
function Engine:KeyDown()
    local key=self.config.Aim.Key
    if key=='none' then return false end
    local ok,down
    if key==Enum.UserInputType.MouseButton1 or key==Enum.UserInputType.MouseButton2 or key==Enum.UserInputType.MouseButton3 then
        ok,down=pcall(function() return Input:IsMouseButtonPressed(key) end)
    else
        ok,down=pcall(function() return Input:IsKeyDown(key) end)
    end
    return ok and down or (not ok and self.held) or false
end
function Engine:Aim(camera, root, dt)
    local a = self.config.Aim
    local active = a.Mode == 'Always' or (a.Mode == 'Hold' and self.held) or (a.Mode == 'Toggle' and self.toggled)
    local blocked
    if not a.Enabled then blocked='Aimbot: OFF'
    elseif not self.focused then blocked='Aimbot: window out of focus'
    elseif not root then blocked='Aimbot: waiting for your character'
    elseif Input:GetFocusedTextBox() then blocked='Aimbot: typing'
    elseif self:PointerBlocked() then blocked='Aimbot: pointer over settings'
    elseif a.PauseMenu and self.library.open then blocked='Aimbot: paused by menu option'
    elseif a.SkipScriptable and camera.CameraType==Enum.CameraType.Scriptable then blocked='Aimbot: Scriptable camera skipped'
    elseif not active then blocked='Aimbot: hold '..(typeof(a.Key)=='EnumItem' and a.Key.Name or 'a bound key') end
    if blocked then self:ResetTarget(); self:SetStatus(blocked); return end
    local candidate = self:Choose(camera, root, os.clock())
    self.aimLine.Visible = candidate ~= nil and a.TargetLine
    if not candidate then
        local reasons={}
        for reason,count in pairs(self.Rejected or {}) do table.insert(reasons,reason..': '..count) end
        table.sort(reasons)
        self:SetStatus('Aimbot: '..(self.pending and 'acquiring target' or 'no target')..(#reasons>0 and ' | '..table.concat(reasons,', ') or ''))
        return
    end
    self:SetStatus('Target: @'..candidate.Player.Name..' / '..candidate.Part.Name)
    self.aimLine.From, self.aimLine.To = camera.ViewportSize/2, candidate.Screen
    self.aimLine.Color, self.aimLine.Transparency = a.TargetColor, a.FOVOpacity*self:Opacity('Aim','TargetColor')
    if candidate.Pixels <= a.Deadzone then return end
    local position, destination = camera.CFrame.Position, candidate.Position
    if a.Axis == 'Horizontal' then
        local delta=destination-position
        local flat=Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude<0.001 then return end
        local pitchY=math.clamp(camera.CFrame.LookVector.Y,-1,1)
        destination=position+(flat.Unit*math.sqrt(math.max(0,1-pitchY*pitchY))+Vector3.new(0,pitchY,0))*delta.Magnitude
    end
    if a.Axis == 'Vertical' then
        local look = camera.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude < 0.001 then return end
        local horizontalDistance = Vector3.new(destination.X-position.X, 0, destination.Z-position.Z).Magnitude
        destination = position + flat.Unit * math.max(horizontalDistance, 0.01) + Vector3.new(0, destination.Y-position.Y, 0)
    end
    if (destination-position).Magnitude < 0.01 then return end
    local alpha = a.Smoothing == 'Instant' and 1 or 1-math.exp(-a.Speed*math.min(dt, 0.1))
    camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(position, destination), alpha)
end
function Engine:NewRecord(other, character)
    local record = {Character=character, Drawings={}, Bones={}}
    record.Highlight = Instance.new('Highlight')
    record.Highlight.Name, record.Highlight.Adornee = 'LegitHighlight', character
    record.Highlight.Parent = self.folder
    local function add(class, props)
        local object = drawing(self.Drawing, class, props)
        table.insert(record.Drawings, object)
        return object
    end
    record.Box = add('Square', {Filled=false, ZIndex=5})
    record.BoxOutline = add('Square', {Filled=false, Color=Color3.new(0,0,0), ZIndex=4})
    record.Fill = add('Square', {Filled=true, ZIndex=3})
    record.Corners, record.CornerOutlines = {}, {}
    for i=1,8 do
        record.Corners[i] = add('Line', {ZIndex=5})
        record.CornerOutlines[i] = add('Line', {Color=Color3.new(0,0,0), ZIndex=4})
    end
    record.Tracer = add('Line', {ZIndex=2})
    record.HealthBackground = add('Square', {Filled=true, Color=Color3.new(0,0,0), ZIndex=5})
    record.HealthBar = add('Square', {Filled=true, ZIndex=6})
    record.TopText = add('Text', {Center=true, Outline=true, ZIndex=7})
    record.BottomText = add('Text', {Center=true, Outline=true, ZIndex=7})
    record.TopTextBorder = add('Text', {Center=true, Outline=true, ZIndex=6})
    record.BottomTextBorder = add('Text', {Center=true, Outline=true, ZIndex=6})
    for i=1,#skeleton do record.Bones[i] = add('Line', {ZIndex=6}) end
    self.records[other] = record
    return record
end
function Engine:RemoveRecord(other)
    local record = self.records[other]
    if not record then return end
    for _, object in ipairs(record.Drawings) do removeDrawing(object) end
    record.Highlight:Destroy()
    self.records[other] = nil
end
function Engine:HideRecord(record)
    record.Highlight.Enabled = false
    for _, object in ipairs(record.Drawings) do object.Visible = false end
end
function Engine:Bounds(character, camera)
    local frame, size = character:GetBoundingBox()
    local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local p = camera:WorldToViewportPoint(frame:PointToWorldSpace(size*Vector3.new(x,y,z)/2))
        if p.Z <= 0.1 then return nil end
        left, top, right, bottom = math.min(left,p.X), math.min(top,p.Y), math.max(right,p.X), math.max(bottom,p.Y)
    end end end
    local viewport = camera.ViewportSize
    if right < 0 or bottom < 0 or left > viewport.X or top > viewport.Y then return nil end
    return Vector2.new(left,top), Vector2.new(math.max(1,right-left),math.max(1,bottom-top))
end
function Engine:Colors(other, visible, now)
    local e, c = self.config.ESP, self.config.Colors
    local fillKey,outlineKey='Fill','Outline'
    if e.VisibleColors then fillKey,outlineKey=visible and 'VisibleFill' or 'HiddenFill',visible and 'VisibleOutline' or 'HiddenOutline' end
    local fill,outline=c[fillKey],c[outlineKey]
    if e.TeamColors and not other.Neutral then fill,outline=other.TeamColor.Color,other.TeamColor.Color; fillKey,outlineKey='Fill','Outline' end
    if e.Rainbow then fill=Color3.fromHSV((now*e.RainbowSpeed)%1,0.8,1); outline=fill; fillKey,outlineKey='Fill','Outline' end
    if e.TargetColor and other == self.target then fill,outline=c.Target,c.Target; fillKey,outlineKey='Target','Target' end
    return fill,outline,self:Opacity('Colors',fillKey),self:Opacity('Colors',outlineKey)
end
function Engine:DrawOverlay(record, other, character, humanoid, root, camera, distance, color, opacity, colorOpacity)
    local o, l = self.config.Overlay, self.config.Labels
    if not (o.Box or o.Tracers or o.Skeleton or o.HealthBar or l.Enabled) then return end
    local position, size = self:Bounds(character, camera)
    if not position then return end
    local bottomCenter = position + Vector2.new(size.X/2,size.Y)
    local boxColor = o.MatchESP and color or self.config.Colors.Box
    local boxOpacity=opacity*(o.MatchESP and colorOpacity or self:Opacity('Colors','Box'))
    if o.Box then
        record.Fill.Position, record.Fill.Size = position,size
        record.Fill.Color, record.Fill.Transparency, record.Fill.Visible = boxColor,o.FillOpacity*boxOpacity,o.BoxFill
        if o.BoxStyle == 'Full' then
            record.Box.Position, record.Box.Size = position,size
            record.Box.Color, record.Box.Thickness = boxColor,o.Thickness
            record.Box.Transparency, record.Box.Visible = boxOpacity,true
            record.BoxOutline.Position, record.BoxOutline.Size = position,size
            record.BoxOutline.Thickness, record.BoxOutline.Transparency = o.Thickness+2,boxOpacity
            record.BoxOutline.Visible = o.BlackOutline
        else
            local x,y,w,h = position.X,position.Y,size.X,size.Y
            local length = math.min(w,h)*o.CornerLength
            local segments = {
                {x,y,x+length,y},{x,y,x,y+length},{x+w,y,x+w-length,y},{x+w,y,x+w,y+length},
                {x,y+h,x+length,y+h},{x,y+h,x,y+h-length},{x+w,y+h,x+w-length,y+h},{x+w,y+h,x+w,y+h-length},
            }
            for i, segment in ipairs(segments) do
                local line, border = record.Corners[i],record.CornerOutlines[i]
                line.From,line.To = Vector2.new(segment[1],segment[2]),Vector2.new(segment[3],segment[4])
                line.Color,line.Thickness,line.Transparency,line.Visible = boxColor,o.Thickness,boxOpacity,true
                border.From,border.To,border.Thickness,border.Transparency,border.Visible = line.From,line.To,o.Thickness+2,boxOpacity,o.BlackOutline
            end
        end
    end
    if o.Tracers then
        local viewport = camera.ViewportSize
        local y = o.TracerOrigin == 'Top' and 0 or o.TracerOrigin == 'Center' and viewport.Y/2 or viewport.Y
        record.Tracer.From,record.Tracer.To = Vector2.new(viewport.X/2,y),bottomCenter
        record.Tracer.Color,record.Tracer.Thickness = self.config.Colors.Tracer,o.TracerThickness
        record.Tracer.Transparency,record.Tracer.Visible = opacity*self:Opacity('Colors','Tracer'),true
    end
    if o.HealthBar then
        local ratio = math.clamp(humanoid.Health/math.max(1,humanoid.MaxHealth),0,1)
        local bar = record.HealthBar
        bar.Position = Vector2.new(position.X-o.HealthWidth-4,position.Y+size.Y*(1-ratio))
        bar.Size,bar.Color = Vector2.new(o.HealthWidth,size.Y*ratio),self.config.Colors.HealthLow:Lerp(self.config.Colors.HealthHigh,ratio)
        bar.Transparency,bar.Visible = opacity*(self:Opacity('Colors','HealthLow')*(1-ratio)+self:Opacity('Colors','HealthHigh')*ratio),ratio>0
        local background = record.HealthBackground
        background.Position,background.Size = Vector2.new(position.X-o.HealthWidth-5,position.Y-1),Vector2.new(o.HealthWidth+2,size.Y+2)
        background.Transparency,background.Visible = opacity,true
    end
    if o.Skeleton then
        for i, pair in ipairs(skeleton) do
            local from,to = character:FindFirstChild(pair[1]),character:FindFirstChild(pair[2])
            if from and to and from:IsA('BasePart') and to:IsA('BasePart') then
                local p1,on1 = point(camera,from.Position)
                local p2,on2 = point(camera,to.Position)
                local line = record.Bones[i]
                line.From,line.To,line.Visible = p1,p2,on1 and on2
                line.Color,line.Thickness,line.Transparency = self.config.Colors.Skeleton,o.SkeletonThickness,opacity*self:Opacity('Colors','Skeleton')
            end
        end
    end
    if l.Enabled then
        local top,bottom = {},{}
        if l.Names then
            local name = l.NameMode == 'Username' and other.Name or l.NameMode == 'Both' and (other.DisplayName..' (@'..other.Name..')') or other.DisplayName
            table.insert(top,name)
        end
        if l.Health then table.insert(bottom,string.format('HP %d / %d',math.ceil(humanoid.Health),math.ceil(humanoid.MaxHealth))) end
        if l.Distance then table.insert(bottom,string.format('%d studs',math.floor(distance))) end
        if l.Tool then
            local tool = character:FindFirstChildOfClass('Tool')
            if tool then table.insert(bottom,tool.Name) end
        end
        if l.Team then table.insert(bottom,other.Team and other.Team.Name or 'Neutral') end
        local labels = {record.TopText,record.BottomText}
        for _, label in ipairs(labels) do
            label.Size,label.Font,label.Outline = l.Size,({UI=0,System=1,Plex=2,Monospace=3})[l.Font],false
            label.Color,label.OutlineColor = self.config.Colors.Text,self.config.Colors.TextOutline
            label.Transparency = opacity*l.Opacity*self:Opacity('Colors','Text')
        end
        record.TopText.Text = table.concat(top,'\n')
        record.TopText.Position = position+Vector2.new(size.X/2,-l.Size-4-l.Offset)
        record.TopText.Visible = #top>0
        record.BottomText.Text = table.concat(bottom,'\n')
        record.BottomText.Position = bottomCenter+Vector2.new(0,4+l.Offset)
        record.BottomText.Visible = #bottom>0
        for index,border in ipairs({record.TopTextBorder,record.BottomTextBorder}) do
            local label=labels[index]
            border.Text,border.Position,border.Size,border.Font=label.Text,label.Position,label.Size,label.Font
            border.Color,border.OutlineColor=self.config.Colors.TextOutline,self.config.Colors.TextOutline
            border.Transparency=opacity*l.Opacity*self:Opacity('Colors','TextOutline')
            border.Visible=label.Visible and l.TextOutline
        end
    end
end
function Engine:ESP(camera, localRoot)
    local e = self.config.ESP
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= self.player then
            local record = self.records[other]
            local character,humanoid,root = characterOf(other)
            local distance = root and localRoot and (root.Position-localRoot.Position).Magnitude or math.huge
            if not e.Enabled or not character or not self:Allowed(other,e) or distance>e.MaxDistance then
                if record then self:RemoveRecord(other) end
            else
                if record and record.Character ~= character then self:RemoveRecord(other); record=nil end
                record = record or self:NewRecord(other,character)
                self:HideRecord(record)
                local visible = self:Visible(character,(character:FindFirstChild('Head') or root).Position,camera)
                if e.ThroughWalls or visible then
                    local fill,outline,fillAlpha,outlineAlpha = self:Colors(other,visible,os.clock())
                    local opacity = e.Opacity
                    if e.Fade then
                        local start = e.MaxDistance*e.FadeStart
                        opacity = opacity * math.clamp((e.MaxDistance-distance)/math.max(1,e.MaxDistance-start),0,1)
                    end
                    local pulse = e.Pulse and (0.65+0.35*(0.5+0.5*math.sin(os.clock()*e.PulseSpeed*math.pi*2))) or 1
                    local highlight = record.Highlight
                    highlight.Enabled = (e.Chams or e.Outline) and opacity>0
                    highlight.DepthMode = e.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
                    highlight.FillColor,highlight.OutlineColor = fill,outline
                    highlight.FillTransparency = e.Chams and 1-e.FillOpacity*opacity*pulse*fillAlpha or 1
                    highlight.OutlineTransparency = e.Outline and 1-e.OutlineOpacity*opacity*pulse*outlineAlpha or 1
                    self:DrawOverlay(record,other,character,humanoid,root,camera,distance,outline,opacity,outlineAlpha)
                end
            end
        end
    end
end
function Engine:Start()
    for _, other in ipairs(Players:GetPlayers()) do self:TrackFriend(other) end
    self:Connect(Players.PlayerAdded,function(other) self:TrackFriend(other) end)
    self:Connect(Players.PlayerRemoving,function(other)
        self:RemoveRecord(other); self.friends[other]=nil
        if self.target == other then self:ResetTarget() end
    end)
    self:Connect(Input.InputBegan,function(input)
        if not Input:GetFocusedTextBox() and not self:PointerBlocked() and (input.KeyCode==self.config.Aim.Key or input.UserInputType==self.config.Aim.Key) then
            if self.config.Aim.PauseMenu and self.library.open then return end
            self.held,self.toggled = true,not self.toggled
        end
    end)
    self:Connect(Input.InputEnded,function(input)
        if input.KeyCode==self.config.Aim.Key or input.UserInputType==self.config.Aim.Key then self.held=false end
    end)
    self:Connect(Input.WindowFocusReleased,function()
        self.focused,self.held,self.toggled=false,false,false; self:ResetTarget()
    end)
    self:Connect(Input.WindowFocused,function() self.focused=true end)
    local elapsed=0
    RunService:BindToRenderStep(self.renderName,Enum.RenderPriority.Last.Value+1,function(dt)
        if not self.alive then return end
        local camera=workspace.CurrentCamera
        if not camera then
            self.fov.Visible,self.deadzone.Visible,self.aimLine.Visible=false,false,false
            for _,record in pairs(self.records) do self:HideRecord(record) end
            self:ResetTarget(); return
        end
        local character,_,root=characterOf(self.player)
        self.ray.FilterDescendantsInstances=character and {character,camera} or {camera}
        if self.config.Aim.Mode=='Hold' then self.held=self:KeyDown() end
        self:Aim(camera,root,dt)
        local a=self.config.Aim
        self.fov.Position,self.fov.Radius=camera.ViewportSize/2,a.Radius
        self.fov.Color=self.target and a.TargetColor or a.FOVColor
        self.fov.Transparency,self.fov.Thickness=a.FOVOpacity*self:Opacity('Aim',self.target and 'TargetColor' or 'FOVColor'),a.FOVThickness
        self.fov.Visible=a.Enabled and a.ShowFOV
        self.deadzone.Position,self.deadzone.Radius=camera.ViewportSize/2,math.min(a.Deadzone,a.Radius)
        self.deadzone.Color,self.deadzone.Transparency=a.FOVColor,a.FOVOpacity*0.5*self:Opacity('Aim','FOVColor')
        self.deadzone.Visible=a.Enabled and a.ShowDeadzone and a.Deadzone>0
        elapsed=elapsed+dt
        if elapsed>=1/self.config.ESP.RefreshRate then elapsed=0; self:ESP(camera,root) end
    end)
end
function Engine:Destroy()
    if not self.alive then return end
    self.alive=false
    RunService:UnbindFromRenderStep(self.renderName)
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    local players={}
    for other in pairs(self.records) do table.insert(players,other) end
    for _,other in ipairs(players) do self:RemoveRecord(other) end
    removeDrawing(self.fov); removeDrawing(self.deadzone); removeDrawing(self.aimLine); self.folder:Destroy()
end
return Engine
