-- Retained application/profile descriptors backed by stable Iris states.
-- Only rendering is repeated; callbacks are attached once and actions run after a cycle.
local Input=game:GetService('UserInputService')
local RunService=game:GetService('RunService')
local UI={}
UI.__index=function(self,key)
    if key=='open' then return self.openState and self.openState.value==true end
    return UI[key]
end
local function signal()
    local handlers={}
    return {Connect=function(_,fn)
        local c={Connected=true}; function c:Disconnect() self.Connected=false end
        table.insert(handlers,{c,fn}); return c
    end,Fire=function()
        for _,item in ipairs(handlers) do if item[1].Connected then item[2]() end end
        table.clear(handlers)
    end}
end
function UI:State(id,value,callback)
    self.Native.PushId('Legit/'..id)
    local state=self.Native.State(value)
    self.Native.PopId()
    if callback then table.insert(self.stateDisposers,state:onChange(function(v) if self.Alive then callback(v) end end)) end
    return state
end
function UI.new(native)
    local self=setmetatable({Native=native,Alive=true,options={},windows={},connections={},stateDisposers={},actions={},
        theme={Accent=Color3.fromRGB(66,150,250)},unloaded=signal(),nextID=0,scale=100},UI)
    self.themes={{theme=self.theme}}
    self.openState=self:State('open',true,function() self:UpdateMouse() end)
    self.NewWindow=function(data) return self:CreateWindow(data) end
    local function connect(event,fn) table.insert(self.connections,event:Connect(fn)) end
    connect(Input.InputBegan,function(input)
        if self.listening then
            local key
            if input.UserInputType==Enum.UserInputType.Keyboard then key=input.KeyCode
            elseif input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.MouseButton2 or input.UserInputType==Enum.UserInputType.MouseButton3 then key=input.UserInputType end
            if key then local option=self.listening; self.listening=nil; option:SetBind(key) end
            return
        end
        local key=self.toggleKey
        if key and key~=Enum.KeyCode.Unknown and (input.KeyCode==key or input.UserInputType==key) then
            local focused=Input:GetFocusedTextBox()
            local nonTextKey=key==Enum.KeyCode.RightShift or key==Enum.KeyCode.LeftShift or key==Enum.KeyCode.Insert
                or key.Name:match('^F%d+$')~=nil
            if not focused or nonTextKey then
                local root=self.Native.Internal._rootInstance
                if focused and root and focused:IsDescendantOf(root) then focused:ReleaseFocus() end
                self:SetOpen(not self.open)
            end
        end
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self.dragging=self:IsPointerOverUI() end
    end)
    connect(Input.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self.dragging=false end
    end)
    connect(Input.WindowFocusReleased,function() self.dragging=false end)
    return self
end
function UI:init()
    local parent=game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')
    self.Gui=Instance.new('ScreenGui'); self.Gui.Name='LegitIrisOverlay'; self.Gui.ResetOnSpawn=false; self.Gui.IgnoreGuiInset=true; self.Gui.Parent=parent
    -- Roblox's modal GUI releases the cursor while allowing RMB camera capture.
    -- Never fight the game's camera by rewriting MouseBehavior every render frame.
    self.modal=Instance.new('TextButton'); self.modal.Name='LegitMenuModal'; self.modal.Text=''
    self.modal.Size=UDim2.fromOffset(1,1); self.modal.BackgroundTransparency=1; self.modal.BorderSizePixel=0
    self.modal.AutoButtonColor=false; self.modal.Selectable=false; self.modal.Modal=true; self.modal.Visible=false; self.modal.Parent=self.Gui
    self.Native.Init(parent,false); self.started=true; self.hasInit=true
    self.disconnectDraw=self.Native:Connect(function() self:Draw() end)
    table.insert(self.connections,RunService.Heartbeat:Connect(function(dt) self:Cycle(dt) end))
end
function UI:Cycle(dt)
    if not self.Alive or not self.started then return end
    local ok,problem=pcall(self.Native.Internal._cycle,dt or 0)
    if not ok then
        self.LastRenderError=tostring(problem)
        if os.clock()>=(self.nextError or 0) then self.nextError=os.clock()+2; warn('[Legit Iris] '..self.LastRenderError) end
    end
    local actions=self.actions; self.actions={}
    for _,callback in ipairs(actions) do if self.Alive then callback() end end
end
function UI:Start() self:Cycle(0); self:UpdateMouse() end
function UI:UpdateMouse()
    if self.modal then self.modal.Visible=self.Alive and self.open end
    if self.Alive and self.open then
        if not self.cursorState then
            self.cursorState={Icon=Input.MouseIconEnabled}
            Input.MouseIconEnabled=true
        end
    elseif self.cursorState then
        if Input.MouseIconEnabled==true then Input.MouseIconEnabled=self.cursorState.Icon end
        self.cursorState=nil
    end
end
function UI:SetOpen(value)
    self.openState:set(value); self:UpdateMouse()
    if not value then self.listening=nil end
end
function UI:SetMenuKey(key) self.toggleKey=typeof(key)=='EnumItem' and key or Enum.KeyCode.Unknown end
function UI:SetScale(value)
    local ratio=value/self.scale; self.scale=value
    if self.windowSize then self.windowSize:set(self.windowSize.value*ratio) end
    local factor=value/100
    self.Native.UpdateGlobalConfig({TextSize=math.round(13*factor),FramePadding=Vector2.new(4,3)*factor,
        WindowPadding=Vector2.new(8,8)*factor,ItemSpacing=Vector2.new(8,4)*factor,ScrollbarSize=math.round(10*factor)})
end
function UI:SetTheme(theme)
    self.theme=theme
    self.Native.UpdateGlobalConfig({CheckMarkColor=theme.Accent,SliderGrabColor=theme.Accent,SliderGrabActiveColor=theme.Accent,
        TabActiveColor=theme.Accent,ButtonHoveredColor=theme.Accent,HeaderHoveredColor=theme.Accent,TitleBgActiveColor=theme.Accent})
end
function UI:SendNotification(message,duration)
    self.LastNotification=message
    if self.notice then self.notice:Destroy() end
    local notice=Instance.new('TextLabel'); self.notice=notice
    notice.Name='LegitNotification'; notice.Text=message; notice.TextWrapped=true; notice.Font=Enum.Font.GothamMedium
    notice.TextSize=14; notice.TextColor3=Color3.new(1,1,1); notice.BackgroundColor3=Color3.fromRGB(20,20,20)
    notice.BackgroundTransparency=0.1; notice.Size=UDim2.fromOffset(360,70); notice.Position=UDim2.new(1,-380,1,-90)
    notice.ZIndex=100; notice.Parent=self.Gui
    task.delay(duration or 5,function() if notice.Parent then notice:Destroy() end end)
end
function UI:SetStatus(message)
    self.Status=message; if self.StatusLabel then self.StatusLabel:SetText('Legit | '..message) end
end
function UI:IsPointerOverUI()
    if not self.Alive then return false end
    local mouse=Input:GetMouseLocation()
    local function over(frame)
        if not frame or not frame.Parent or not frame:IsA('GuiObject') then return false end
        local current=frame
        while current do
            if current:IsA('GuiObject') and not current.Visible then return false end
            if current:IsA('ScreenGui') and not current.Enabled then return false end
            current=current.Parent
        end
        local p,s=frame.AbsolutePosition,frame.AbsoluteSize
        return mouse.X>=p.X and mouse.X<=p.X+s.X and mouse.Y>=p.Y and mouse.Y<=p.Y+s.Y
    end
    if self.open and self.windowWidget then
        local main=self.windowWidget.Instance:FindFirstChild('WindowButton') or self.windowWidget.Instance
        if over(main) then return true end
        local root=self.Native.Internal._rootInstance
        local popup=root and root:FindFirstChild('PopupScreenGui')
        if popup then for _,frame in ipairs(popup:GetDescendants()) do if over(frame) then return true end end end
    end
    if self.Gui then for _,frame in ipairs(self.Gui:GetChildren()) do if over(frame) then return true end end end
    return false
end
function UI:IsInteracting() return self.dragging==true or self.listening~=nil or Input:GetFocusedTextBox()~=nil end
function UI:Unload()
    if not self.Alive then return end
    self.Alive=false; self:UpdateMouse()
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    for _,dispose in ipairs(self.stateDisposers) do dispose() end
    if self.disconnectDraw then self.disconnectDraw() end
    self.unloaded:Fire()
    if self.started then self.Native.Shutdown() end
    if self.Gui then self.Gui:Destroy() end
    self.actions={}; self.listening=nil
end
function UI:CreateWindow(data)
    local owner=self
    self.windowSize=self:State('size',Vector2.new(880,660)); self.windowPosition=self:State('position',Vector2.new(80,70))
    self.tabIndex=self:State('tab',1)
    self.Window={SetOpen=function(_,v) owner:SetOpen(v) end}
    local status=Instance.new('TextLabel'); status.Name='LegitStatus'; status.Visible=false; status.Text='Legit'
    status.TextColor3=Color3.new(1,1,1); status.TextSize=13; status.BackgroundColor3=Color3.fromRGB(20,20,20)
    status.Size=UDim2.fromOffset(330,25); status.Position=UDim2.fromOffset(15,15); status.Parent=self.Gui
    self.StatusLabel={SetText=function(_,v) status.Text=v end,SetVisible=function(_,v) status.Visible=v end}
    local window={tabs={},title=data.title}; table.insert(self.windows,window)
    function window:AddTab(name)
        local tab={name=name,sections={},index=#self.tabs+1}; table.insert(self.tabs,tab)
        function tab:Select() owner.tabIndex:set(self.index) end
        function tab:AddSection(name,side)
            owner.nextID+=1
            local section={name=name,side=side or 1,id='section'..owner.nextID,options={}}
            section.expanded=owner:State(section.id,true); table.insert(self.sections,section)
            local function register(data,kind,initial,callback)
                owner.nextID+=1
                local option={text=data.text,class=kind,id=data.flag or 'option'..owner.nextID,data=data}
                table.insert(section.options,option); if data.flag then owner.options[data.flag]=option end
                if kind~='button' and kind~='text' then option.State=owner:State(option.id,initial,function(v) if not option.muted and callback then callback(v) end end) end
                return option
            end
            function section:AddToggle(data)
                local option=register(data,'toggle',data.state,data.callback)
                function option:SetState(v) self.State:set(v,true) end
                return option
            end
            function section:AddSlider(data)
                local option=register(data,'slider',data.value,data.callback)
                function option:SetValue(v) self.State:set(math.clamp(v,data.min,data.max),true) end
                return option
            end
            function section:AddList(data)
                local option=register(data,'list',data.selected,data.callback); option.values=data.values
                function option:Select(v,silent) self.muted=silent; self.State:set(v,true); self.muted=false end
                function option:SetValues(values) self.values=values end
                return option
            end
            function section:AddBind(data)
                local option=register(data,'bind',data.bind,data.keycallback)
                function option:SetBind(v)
                    if v==nil or v==Enum.KeyCode.Escape or v==Enum.KeyCode.Backspace then v='none' end
                    self.State:set(v,true)
                end
                return option
            end
            function section:AddColor(data)
                local option
                local function changed()
                    if option and not option.batch and data.callback then data.callback(option.State.value,option.Transparency.value) end
                end
                option=register(data,'color',data.color,changed)
                option.Transparency=owner:State(option.id..'/alpha',0,changed)
                function option:SetColor(v) self.State:set(v,true) end
                function option:SetTrans(v) self.Transparency:set(math.clamp(v,0,1),true) end
                return option
            end
            function section:AddBox(data)
                local option=register(data,'box',data.input or '',data.callback)
                function option:SetInput(v) self.State:set(v,true) end
                return option
            end
            function section:AddButton(data)
                local option=register(data,'button'); option.callback=data.callback; return option
            end
            function section:AddText(data)
                local option=register(data,'text')
                function option:SetText(v) self.text=v end
                return option
            end
            return section
        end
        return tab
    end
    return window
end
function UI:DrawOption(option)
    local iris,data=self.Native,option.data
    iris.PushId(option.id)
    iris.SetNextWidgetID(option.id)
    local kind=option.class
    if kind=='toggle' then option.Widget=iris.Checkbox({option.text},{isChecked=option.State})
    elseif kind=='slider' then option.Widget=iris.SliderNum({option.text..(data.suffix and data.suffix~='' and (' ['..data.suffix..']') or ''),data.increment,data.min,data.max},{number=option.State})
    elseif kind=='list' then option.Widget=iris.ComboArray({option.text},{index=option.State},option.values)
    elseif kind=='color' then option.Widget=iris.InputColor4({option.text},{color=option.State,transparency=option.Transparency})
    elseif kind=='box' then option.Widget=iris.InputText({option.text},{text=option.State})
    elseif kind=='text' then iris.TextWrapped({option.text})
    elseif kind=='bind' then
        local key=option.State.value; local label=self.listening==option and 'press a key / mouse button' or (typeof(key)=='EnumItem' and key.Name or 'None')
        if iris.Button({option.text..': '..label}).clicked() then self.listening=option end
    elseif kind=='button' then
        local confirming=option.confirmUntil and os.clock()<option.confirmUntil
        if iris.Button({(confirming and 'Confirm: ' or '')..option.text}).clicked() then
            if data.confirm and not confirming then option.confirmUntil=os.clock()+3
            else option.confirmUntil=nil; table.insert(self.actions,option.callback) end
        end
    end
    iris.PopId()
end
function UI:Draw()
    local window=self.windows[1]; if not window then return end
    local iris=self.Native
    iris.SetNextWidgetID('LegitWindow')
    self.windowWidget=iris.Window({window.title,[iris.Args.Window.NoCollapse]=true},
        {isOpened=self.openState,size=self.windowSize,position=self.windowPosition})
    if self.open then
        iris.SetNextWidgetID('LegitTabs'); iris.TabBar({}, {index=self.tabIndex})
        for _,tab in ipairs(window.tabs) do
            iris.SetNextWidgetID('tab/'..tab.name); iris.Tab({tab.name})
            if self.tabIndex.value==tab.index then
                iris.SetNextWidgetID('columns/'..tab.name); iris.Table({2,false,false,false,false})
                for side=1,2 do
                    if side==2 then iris.NextColumn() end
                    iris.SetNextWidgetID('group/'..tab.name..'/'..side)
                    iris.Group()
                    for _,section in ipairs(tab.sections) do
                        if section.side==side then
                            iris.SetNextWidgetID(section.id); iris.CollapsingHeader({section.name},{isUncollapsed=section.expanded})
                            if section.expanded.value then for _,option in ipairs(section.options) do self:DrawOption(option) end end
                            iris.End()
                        end
                    end
                    iris.End()
                end
                iris.End()
            end
            iris.End()
        end
        iris.End()
    end
    iris.End()
end
return UI
