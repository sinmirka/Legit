-- Original Player Tools style: standard Roblox GUI, rounded dark panels and purple controls.
local Input=game:GetService('UserInputService')
local Players=game:GetService('Players')
local NativeUI={}
local accent=Color3.fromRGB(151,118,255)
local foreground=Color3.fromRGB(231,232,241)
local function create(class,props,parent)
    local object=Instance.new(class)
    for key,value in pairs(props or {}) do object[key]=value end
    object.Parent=parent
    return object
end
local function corner(object) create('UICorner',{CornerRadius=UDim.new(0,7)},object) end
local function text(parent,value,props)
    local p={Text=value,TextColor3=foreground,TextSize=13,Font=Enum.Font.Gotham,
        BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,30)}
    for key,item in pairs(props or {}) do p[key]=item end
    return create('TextLabel',p,parent)
end
local function button(parent,label,props)
    local p={Text=label,TextColor3=foreground,TextSize=12,Font=Enum.Font.GothamMedium,
        BackgroundColor3=Color3.fromRGB(45,46,62),BorderSizePixel=0,AutoButtonColor=true}
    for key,item in pairs(props or {}) do p[key]=item end
    local object=create('TextButton',p,parent); corner(object); return object
end
local function box(parent,props)
    local p={Text='',TextColor3=foreground,TextSize=12,Font=Enum.Font.Code,ClearTextOnFocus=false,
        BackgroundColor3=Color3.fromRGB(40,41,56),BorderSizePixel=0}
    for key,item in pairs(props or {}) do p[key]=item end
    local object=create('TextBox',p,parent); corner(object); return object
end
local function signal()
    local self={handlers={}}
    function self:Connect(callback)
        local connection={Connected=true}
        function connection:Disconnect() self.Connected=false end
        table.insert(self.handlers,{connection,callback})
        return connection
    end
    function self:Fire(...)
        for _,entry in ipairs(table.clone(self.handlers)) do
            if entry[1].Connected then
                local ok,message=pcall(entry[2],...)
                if not ok then warn('[Legit UI] '..tostring(message)) end
            end
        end
    end
    return self
end
function NativeUI.new()
    local lib={options={},flags={},windows={},connections={},open=true,hasInit=false,Alive=true,
        toggleKey=Enum.KeyCode.RightShift,theme={Accent=accent},themes={{theme={Accent=accent}}},unloaded=signal(),Status='Aimbot: OFF'}
    local sliderDrag,windowDrag,binding=nil,nil,nil
    local themed={}
    local function listen(event,callback)
        local connection=event:Connect(callback); table.insert(lib.connections,connection); return connection
    end
    local function theme(object) themed[object]=true; object.BackgroundColor3=lib.theme.Accent end
    local function inside(object,position)
        local p,s=object.AbsolutePosition,object.AbsoluteSize
        return object.Visible and p and s and position.X>=p.X and position.Y>=p.Y and position.X<=p.X+s.X and position.Y<=p.Y+s.Y
    end
    function lib:IsPointerOverUI()
        local position=Input:GetMouseLocation()
        if self.Reopen and inside(self.Reopen,position) then return true end
        return self.open and self.windows[1] and inside(self.windows[1].Frame,position) or false
    end
    function lib:IsInteracting() return binding~=nil or sliderDrag~=nil or windowDrag~=nil end
    function lib:SetTheme(value)
        self.theme=value
        for object in pairs(themed) do object.BackgroundColor3=value.Accent end
    end
    function lib:SetStatus(value)
        self.Status=value
        if self.StatusLabel then self.StatusLabel.Text=value end
        if self.CompactStatus then self.CompactStatus.Text=value end
    end
    function lib:SendNotification(value,duration)
        self.NoticeUntil=os.clock()+(duration or 4)
        if self.NoticeLabel then self.NoticeLabel.Text=tostring(value) end
    end
    function lib:SetOpen(value)
        self.open=value; sliderDrag=nil; windowDrag=nil
        for _,window in ipairs(self.windows) do window.Frame.Visible=value end
        if self.Reopen then self.Reopen.Visible=not value end
        if self.CompactStatus then self.CompactStatus.Visible=not value end
    end
    function lib:Unload()
        if not self.Alive then return end
        self.Alive=false; self.open=false
        self.unloaded:Fire()
        for _,connection in ipairs(self.connections) do connection:Disconnect() end
        if self.Gui then self.Gui:Destroy() end
        if getgenv().library==self then getgenv().library=nil end
    end
    function lib:init()
        if self.hasInit then return end
        local previous=getgenv().library
        if previous and previous~=self and type(previous.Unload)=='function' then pcall(previous.Unload,previous) end
        getgenv().library=self
        for _,path in ipairs({'Legit','Legit/Universal','Legit/Universal/configs'}) do pcall(makefolder,path) end
        local playerGui=Players.LocalPlayer:WaitForChild('PlayerGui')
        local old=playerGui:FindFirstChild('PlayerToolsUI')
        if old then old:Destroy() end
        self.Gui=create('ScreenGui',{Name='PlayerToolsUI',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=210,
            ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
        self.Reopen=button(self.Gui,'TOOLS',{Position=UDim2.fromOffset(12,12),Size=UDim2.fromOffset(72,30),Visible=false})
        self.CompactStatus=text(self.Gui,self.Status,{Position=UDim2.fromOffset(12,48),Size=UDim2.new(1,-24,0,30),
            TextSize=12,TextStrokeTransparency=0.4,Visible=false,TextTruncate=Enum.TextTruncate.AtEnd})
        listen(self.Reopen.Activated,function() self:SetOpen(true) end)
        listen(self.Gui.Destroying,function() self:Unload() end)
        listen(Input.InputBegan,function(input,processed)
            if binding then
                local key=input.KeyCode
                if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.MouseButton2 or input.UserInputType==Enum.UserInputType.MouseButton3 then key=input.UserInputType end
                if key==Enum.KeyCode.Escape then binding.Control.Text=typeof(binding.bind)=='EnumItem' and binding.bind.Name or 'NONE'; binding=nil; return end
                if key and key~=Enum.KeyCode.Unknown then local option=binding; binding=nil; option:SetBind(key) end
                return
            end
            if not Input:GetFocusedTextBox() and input.KeyCode==self.toggleKey then self:SetOpen(not self.open) end
        end)
        listen(Input.InputChanged,function(input)
            if sliderDrag and (input==sliderDrag.Input or input.UserInputType==Enum.UserInputType.MouseMovement) then sliderDrag.Update(input.Position.X)
            elseif windowDrag and (input==windowDrag.Input or input.UserInputType==Enum.UserInputType.MouseMovement) then
                local camera=workspace.CurrentCamera
                local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
                local delta=input.Position-windowDrag.Start
                local frame=windowDrag.Frame
                frame.Position=UDim2.fromOffset(math.clamp(windowDrag.Position.X.Offset+delta.X,0,math.max(0,viewport.X-frame.AbsoluteSize.X)),
                    math.clamp(windowDrag.Position.Y.Offset+delta.Y,0,math.max(0,viewport.Y-frame.AbsoluteSize.Y)))
            end
        end)
        listen(Input.InputEnded,function(input)
            if sliderDrag and (input==sliderDrag.Input or input.UserInputType==Enum.UserInputType.MouseButton1) then sliderDrag=nil end
            if windowDrag and (input==windowDrag.Input or input.UserInputType==Enum.UserInputType.MouseButton1) then windowDrag=nil end
        end)
        listen(Input.WindowFocusReleased,function() sliderDrag=nil; windowDrag=nil end)
        listen(game:GetService('RunService').RenderStepped,function()
            if self.NoticeLabel and self.NoticeUntil and os.clock()>self.NoticeUntil then
                self.NoticeLabel.Text='ESP / AIM  |  RightShift - menu'; self.NoticeUntil=nil
            end
            local camera=workspace.CurrentCamera
            if not camera then return end
            for _,window in ipairs(self.windows) do
                if window.Viewport~=camera.ViewportSize then window:Resize(camera.ViewportSize) end
            end
        end)
        self.hasInit=true
    end
    local function register(section,data,kind)
        local option={class=kind,text=data.text or '',flag=data.flag,callback=data.callback or function() end,objects={}}
        table.insert(section.options,option)
        if data.flag then lib.options[data.flag]=option end
        return option
    end
    local function row(section,label,height)
        local frame=create('Frame',{Size=UDim2.new(1,0,0,height or 36),BackgroundColor3=Color3.fromRGB(29,30,42),BorderSizePixel=0,
            LayoutOrder=#section.options},section.Holder)
        corner(frame)
        text(frame,label,{Position=UDim2.fromOffset(10,0),Size=UDim2.new(1,-84,0,32),TextTruncate=Enum.TextTruncate.AtEnd})
        return frame
    end
    local function slider(parent,y,minimum,maximum,setter,value)
        local track=button(parent,'',{Position=UDim2.new(0,10,0,y),Size=UDim2.new(1,-20,0,12),AutoButtonColor=false})
        local fill=create('Frame',{BackgroundColor3=lib.theme.Accent,BorderSizePixel=0,Size=UDim2.new(0,0,1,0)},track)
        corner(fill); theme(fill)
        local function display(number) fill.Size=UDim2.new(math.clamp((number-minimum)/(maximum-minimum),0,1),0,1,0) end
        listen(track.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                local function update(x)
                    local fraction=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
                    setter(minimum+(maximum-minimum)*fraction)
                end
                sliderDrag={Input=input,Update=update}; update(input.Position.X)
            end
        end)
        display(value)
        return display
    end
    function lib.NewWindow(data)
        local window={tabs={}}
        local camera=workspace.CurrentCamera
        local view=camera and camera.ViewportSize or Vector2.new(1280,720)
        local width,height=math.min(690,math.max(320,view.X-24)),math.min(620,math.max(300,view.Y-40))
        local frame=create('Frame',{Name='Window',Position=UDim2.fromOffset(math.max(0,(view.X-width)/2),math.max(0,(view.Y-height)/2)),
            Size=UDim2.fromOffset(width,height),BackgroundColor3=Color3.fromRGB(22,23,32),BorderSizePixel=0,Active=true,Visible=true},lib.Gui)
        corner(frame); create('UIStroke',{Color=Color3.fromRGB(65,60,88),Thickness=1},frame)
        window.Frame=frame; table.insert(lib.windows,window)
        function window:Resize(viewport)
            self.Viewport=viewport
            local w,h=math.min(690,math.max(1,viewport.X-24)),math.min(620,math.max(1,viewport.Y-40))
            frame.Size=UDim2.fromOffset(w,h)
            frame.Position=UDim2.fromOffset(math.clamp(frame.Position.X.Offset,0,math.max(0,viewport.X-w)),math.clamp(frame.Position.Y.Offset,0,math.max(0,viewport.Y-h)))
        end
        local header=create('Frame',{Size=UDim2.new(1,0,0,55),BackgroundTransparency=1,Active=true},frame)
        text(header,'PLAYER TOOLS',{Position=UDim2.fromOffset(16,5),Font=Enum.Font.GothamBold,TextSize=16})
        lib.NoticeLabel=text(header,'ESP / AIM  |  RightShift - menu',{Position=UDim2.fromOffset(16,30),TextSize=11,TextColor3=Color3.fromRGB(153,155,174)})
        local hide=button(header,'-',{Position=UDim2.new(1,-44,0,12),Size=UDim2.fromOffset(28,28),Modal=true})
        listen(hide.Activated,function() lib:SetOpen(false) end)
        listen(header.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                windowDrag={Input=input,Start=input.Position,Position=frame.Position,Frame=frame}
            end
        end)
        local tabs=create('ScrollingFrame',{Position=UDim2.fromOffset(12,65),Size=UDim2.new(1,-24,0,36),
            BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,
            ScrollingDirection=Enum.ScrollingDirection.X},frame)
        create('UIListLayout',{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,5)},tabs)
        lib.StatusLabel=text(frame,lib.Status,{Position=UDim2.new(0,14,1,-38),Size=UDim2.new(1,-28,0,30),TextSize=11,TextWrapped=true})
        function window:AddTab(name)
            local tab={sections={},text=name}
            table.insert(self.tabs,tab)
            local control=button(tabs,name,{Size=UDim2.fromOffset(86,30)})
            local page=create('ScrollingFrame',{Position=UDim2.fromOffset(12,112),Size=UDim2.new(1,-24,1,-160),BackgroundTransparency=1,
                BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=lib.theme.Accent,CanvasSize=UDim2.new(),
                AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,Visible=false},frame)
            tab.Control,tab.Page=control,page
            local columns={}
            for side=1,2 do
                columns[side]=create('Frame',{Position=UDim2.new((side-1)*0.5,side==1 and 0 or 5,0,0),Size=UDim2.new(0.5,-9,0,0),
                    AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1},page)
                create('UIListLayout',{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},columns[side])
            end
            function tab:Select()
                window.selectedTab=self
                for _,other in ipairs(window.tabs) do
                    other.Page.Visible=other==self
                    if other==self then theme(other.Control) else themed[other.Control]=nil; other.Control.BackgroundColor3=Color3.fromRGB(45,46,62) end
                end
            end
            listen(control.Activated,function() tab:Select() end)
            function tab:AddSection(label,side)
                local section={options={}}
                table.insert(self.sections,section)
                section.Holder=create('Frame',{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,
                    LayoutOrder=#self.sections},columns[side or 1])
                create('UIListLayout',{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},section.Holder)
                text(section.Holder,label,{Size=UDim2.new(1,0,0,28),LayoutOrder=-1,Font=Enum.Font.GothamMedium,TextColor3=lib.theme.Accent})
                function section:AddToggle(d)
                    local option=register(self,d,'toggle'); option.state=d.state or false
                    local holder=row(self,option.text)
                    local control=button(holder,'',{Position=UDim2.new(1,-66,0,6),Size=UDim2.fromOffset(56,24)})
                    option.Control=control
                    function option:SetState(value,silent)
                        self.state=value==true; lib.flags[self.flag]=self.state; control.Text=self.state and 'ON' or 'OFF'
                        if self.state then theme(control) else themed[control]=nil; control.BackgroundColor3=Color3.fromRGB(45,46,62) end
                        if not silent then self.callback(self.state) end
                    end
                    listen(control.Activated,function() option:SetState(not option.state) end)
                    option:SetState(option.state,true); return option
                end
                function section:AddSlider(d)
                    local option=register(self,d,'slider'); option.min,option.max,option.increment=d.min,d.max,d.increment or 1
                    local holder=row(self,option.text,60)
                    local input=box(holder,{Position=UDim2.new(1,-80,0,5),Size=UDim2.fromOffset(70,24)})
                    option.Input=input
                    local display
                    function option:SetValue(value,silent)
                        value=math.clamp(self.min+math.floor((value-self.min)/self.increment+0.5)*self.increment,self.min,self.max)
                        self.value=value; lib.flags[self.flag]=value; input.Text=string.format('%.4g',value)
                        if display then display(value) end
                        if not silent then self.callback(value) end
                    end
                    display=slider(holder,40,d.min,d.max,function(value) option:SetValue(value) end,d.value)
                    listen(input.FocusLost,function() local number=tonumber(input.Text); option:SetValue(number and number==number and number or option.value) end)
                    option:SetValue(d.value,true); return option
                end
                function section:AddList(d)
                    local option=register(self,d,'list'); option.values=d.values
                    local holder=row(self,option.text,64)
                    local control=button(holder,'',{Position=UDim2.fromOffset(10,30),Size=UDim2.new(1,-20,0,26)})
                    option.Control=control
                    function option:Select(value,silent)
                        if not table.find(self.values,value) then return end
                        self.selected=value; lib.flags[self.flag]=value; control.Text=tostring(value)..'  >'
                        if not silent then self.callback(value) end
                    end
                    listen(control.Activated,function() local index=table.find(option.values,option.selected) or 1; option:Select(option.values[index%#option.values+1]) end)
                    option:Select(d.selected or d.values[1],true); return option
                end
                function section:AddColor(d)
                    local option=register(self,d,'color'); option.trans=d.trans or 0
                    local holder=row(self,option.text,106)
                    local swatch=create('Frame',{Position=UDim2.new(1,-124,0,10),Size=UDim2.fromOffset(16,16),BorderSizePixel=0},holder)
                    corner(swatch)
                    local hex=box(holder,{Position=UDim2.new(1,-104,0,5),Size=UDim2.fromOffset(94,24)})
                    local channels={}
                    option.Hex,option.Channels=hex,channels
                    for i,label in ipairs({'R','G','B'}) do
                        text(holder,label,{Position=UDim2.new((i-1)/3,10,0,35),Size=UDim2.fromOffset(18,24),TextSize=11})
                        channels[i]=box(holder,{Position=UDim2.new((i-1)/3,29,0,35),Size=UDim2.new(1/3,-40,0,24)})
                    end
                    local alphaDisplay
                    function option:SetColor(value,silent)
                        self.color=value; lib.flags[self.flag]=value
                        hex.Text=string.format('#%02X%02X%02X',math.floor(value.R*255+0.5),math.floor(value.G*255+0.5),math.floor(value.B*255+0.5))
                        swatch.BackgroundColor3=value
                        channels[1].Text=tostring(math.floor(value.R*255+0.5)); channels[2].Text=tostring(math.floor(value.G*255+0.5)); channels[3].Text=tostring(math.floor(value.B*255+0.5))
                        if not silent then self.callback(value,self.trans) end
                    end
                    function option:SetTrans(value,silent)
                        self.trans=math.clamp(value,0,1)
                        if alphaDisplay then alphaDisplay(1-self.trans) end
                        if not silent then self.callback(self.color,self.trans) end
                    end
                    text(holder,'Opacity',{Position=UDim2.fromOffset(10,60),TextSize=10,Size=UDim2.new(1,-20,0,20)})
                    alphaDisplay=slider(holder,84,0,1,function(value) option:SetTrans(1-value) end,1-option.trans)
                    listen(hex.FocusLost,function()
                        local value=hex.Text:gsub('#',''):gsub('%s','')
                        if #value==6 and value:match('^%x+$') then option:SetColor(Color3.fromRGB(tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16)))
                        else option:SetColor(option.color,true) end
                    end)
                    for _,input in ipairs(channels) do listen(input.FocusLost,function()
                        local r,g,b=tonumber(channels[1].Text),tonumber(channels[2].Text),tonumber(channels[3].Text)
                        if r and g and b then option:SetColor(Color3.fromRGB(math.clamp(r,0,255),math.clamp(g,0,255),math.clamp(b,0,255))) else option:SetColor(option.color,true) end
                    end) end
                    option:SetColor(d.color,true); return option
                end
                function section:AddBind(d)
                    local option=register(self,d,'bind'); option.keycallback=d.keycallback or function() end
                    local holder=row(self,option.text,64)
                    option.Control=button(holder,'',{Position=UDim2.fromOffset(10,30),Size=UDim2.new(1,-20,0,26)})
                    function option:SetBind(value)
                        self.bind=value==Enum.KeyCode.Backspace and 'none' or value
                        option.Control.Text=typeof(self.bind)=='EnumItem' and self.bind.Name or 'NONE'
                        self.keycallback(self.bind)
                    end
                    listen(option.Control.Activated,function() binding=option; option.Control.Text='Press a key / mouse button...' end)
                    option:SetBind(d.bind); return option
                end
                function section:AddBox(d)
                    local option=register(self,d,'box')
                    local holder=row(self,option.text,64)
                    local input=box(holder,{Position=UDim2.fromOffset(10,30),Size=UDim2.new(1,-20,0,26)})
                    option.Input=input
                    function option:SetInput(value,silent) self.input=value; input.Text=value; lib.flags[self.flag]=value; if not silent then self.callback(value) end end
                    listen(input.FocusLost,function() option:SetInput(input.Text) end)
                    option:SetInput(d.input or '',true); return option
                end
                function section:AddButton(d)
                    local option=register(self,d,'button')
                    local holder=row(self,'')
                    local control=button(holder,option.text,{Position=UDim2.fromOffset(6,4),Size=UDim2.new(1,-12,1,-8)})
                    option.Control=control
                    local confirmUntil=0
                    listen(control.Activated,function()
                        if d.confirm and os.clock()>confirmUntil then confirmUntil=os.clock()+3; control.Text='Confirm: '..option.text; return end
                        confirmUntil=0; control.Text=option.text; option.callback()
                    end)
                    return option
                end
                function section:AddText(d) local option=register(self,d,'text'); row(self,option.text); return option end
                return section
            end
            if #window.tabs==1 then tab:Select() end
            return tab
        end
        return window
    end
    return lib
end
return NativeUI
