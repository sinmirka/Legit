-- Bridge the application option/profile contract to the vendored Neverlose controls.
local Input=game:GetService('UserInputService')
local RunService=game:GetService('RunService')
local UI={}
UI.__index=function(self,key)
    if key=='open' then return self.Window and self.Window.Main.Visible or false end
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
function UI.new(native)
    local self=setmetatable({Native=native,Alive=true,options={},windows={},connections={},
        theme={Accent=native.Theme.Accent},unloaded=signal()},UI)
    self.themes={{theme=self.theme}}
    self.NewWindow=function(data) return self:CreateWindow(data) end
    local function connect(event,fn) table.insert(self.connections,event:Connect(fn)) end
    connect(Input.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self.dragging=self:IsPointerOverUI() end
    end)
    connect(Input.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self.dragging=false end
    end)
    connect(Input.WindowFocusReleased,function() self.dragging=false end)
    connect(RunService.RenderStepped,function() self:UpdateMouse() end)
    return self
end
function UI:init() self.hasInit=true end
function UI:UpdateMouse()
    if self.Alive and self.open then
        if not self.mouseState then self.mouseState={Behavior=Input.MouseBehavior,Icon=Input.MouseIconEnabled} end
        Input.MouseBehavior=Enum.MouseBehavior.Default; Input.MouseIconEnabled=true
    elseif self.mouseState then
        if Input.MouseBehavior==Enum.MouseBehavior.Default then Input.MouseBehavior=self.mouseState.Behavior end
        if Input.MouseIconEnabled==true then Input.MouseIconEnabled=self.mouseState.Icon end
        self.mouseState=nil
    end
end
function UI:SetOpen(value)
    if not self.Window then return end
    self.Window:SetOpen(value)
    self:UpdateMouse()
    if not value then
        for _,child in ipairs(self.Gui:GetChildren()) do
            if child~=self.Window.Main and child:IsA('GuiObject') and child.Name~='LegitStatus' then child.Visible=false end
        end
    end
end
function UI:SetScale(value)
    if not self.scale then self.scale=Instance.new('UIScale'); self.scale.Parent=self.Window.Main end
    self.scale.Scale=value/100
end
function UI:SetTheme(theme)
    local old=self.Native.Theme.Accent
    self.Native.Theme.Accent=theme.Accent; self.theme=theme
    if self.Gui then
        for _,object in ipairs(self.Gui:GetDescendants()) do
            for _,property in ipairs({'BackgroundColor3','TextColor3','ImageColor3'}) do
                pcall(function() if object[property]==old then object[property]=theme.Accent end end)
            end
        end
    end
end
function UI:SetMenuKey(key) self.Native.ToggleKey=typeof(key)=='EnumItem' and key or Enum.KeyCode.Unknown end
function UI:SendNotification(message,duration)
    self.LastNotification=message
    if not self.Gui then return end
    if self.notice then self.notice:Destroy() end
    local notice=Instance.new('TextLabel'); self.notice=notice
    notice.Name='LegitNotification'; notice.Text=message; notice.TextWrapped=true; notice.Font=Enum.Font.GothamMedium
    notice.TextSize=14; notice.TextColor3=Color3.new(1,1,1); notice.BackgroundColor3=Color3.fromRGB(8,14,24)
    notice.BackgroundTransparency=0.1; notice.Size=UDim2.fromOffset(360,70); notice.Position=UDim2.new(1,-380,1,-90)
    notice.ZIndex=100; notice.Parent=self.Gui
    task.delay(duration or 5,function() if notice.Parent then notice:Destroy() end end)
end
function UI:SetStatus(message)
    self.Status=message
    if self.StatusLabel then self.StatusLabel:SetText('Legit | '..message) end
end
function UI:IsPointerOverUI()
    if not self.Alive or not self.Gui then return false end
    local mouse=Input:GetMouseLocation()
    local function over(frame)
        if not frame or not frame.Parent or not frame.Visible then return false end
        local p,s=frame.AbsolutePosition,frame.AbsoluteSize
        return mouse.X>=p.X and mouse.X<=p.X+s.X and mouse.Y>=p.Y and mouse.Y<=p.Y+s.Y
    end
    if self.open and over(self.Window.Main) then return true end
    for _,frame in ipairs(self.Gui:GetChildren()) do if frame:IsA('GuiObject') and over(frame) then return true end end
    return false
end
function UI:IsInteracting() return self.dragging==true or self.Native.IsPicking==true or Input:GetFocusedTextBox()~=nil end
function UI:Unload()
    if not self.Alive then return end
    self.Alive=false
    self:UpdateMouse()
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.unloaded:Fire()
    if self.Window then self.Window:Destroy() end
end
function UI:CreateWindow(data)
    local owner=self
    self:SetMenuKey(self.toggleKey or Enum.KeyCode.RightShift)
    local raw=self.Native:CreateWindow({Title='LEGIT',Blur=0,User=game:GetService('Players').LocalPlayer.Name,Till='Criminality',OnSave=function()
        for _,window in ipairs(owner.windows) do for _,tab in ipairs(window.tabs) do for _,section in ipairs(tab.sections) do
            for _,option in ipairs(section.options) do if option.text=='Save profile' and option.callback then option.callback(); return end end
        end end end
    end})
    self.Window=raw; self.Gui=raw.Gui
    local status=Instance.new('TextLabel'); status.Name='LegitStatus'; status.Visible=false; status.Text='Legit'
    status.TextColor3=Color3.new(1,1,1); status.TextSize=13; status.BackgroundColor3=Color3.fromRGB(8,14,24)
    status.Size=UDim2.fromOffset(330,25); status.Position=UDim2.fromOffset(15,15); status.Parent=self.Gui
    self.StatusLabel={SetText=function(_,v) status.Text=v end,SetVisible=function(_,v) status.Visible=v end}
    local window={tabs={},Raw=raw}; table.insert(self.windows,window)
    local icons={Aimbot='crosshairs',Combat='dagger',Character='user',ESP='ghost',World='pallet',Misc='hammer',Players='user',['UI Settings']='code'}
    function window:AddTab(name)
        local tab={name=name,sections={},Raw=raw:AddTab(name,owner.Native.Icons[icons[name]])}
        table.insert(self.tabs,tab)
        function tab:Select() self.Raw:Select() end
        function tab:AddSection(name,side)
            local group=self.Raw:AddGroup(name,nil,side==2 and 'Right' or 'Left')
            local section={options={},Raw=group}; table.insert(self.sections,section)
            local function register(data,kind)
                local option={text=data.text,class=kind}; table.insert(section.options,option)
                if data.flag then owner.options[data.flag]=option end
                return option
            end
            function section:AddToggle(data)
                local option=register(data,'toggle')
                option.Raw=group:AddCheckbox({Name=data.text,Flag=data.flag,Default=data.state,Callback=function(v)
                    option.state=v; if data.callback then data.callback(v) end
                end})
                function option:SetState(v) self.Raw:Set(v) end
                return option
            end
            function section:AddSlider(data)
                local option=register(data,'slider'); local decimals,step=0,data.increment or 1
                while decimals<4 and math.abs(step-math.round(step))>0.00001 do decimals+=1; step*=10 end
                option.Raw=group:AddSlider({Name=data.text,Flag=data.flag,Default=data.value,Min=data.min,Max=data.max,
                    Decimals=decimals,Suffix=data.suffix,Callback=data.callback})
                function option:SetValue(v) self.Raw:Set(v,true) end
                return option
            end
            function section:AddList(data)
                local option=register(data,'list')
                option.Raw=group:AddDropdown({Name=data.text,Flag=data.flag,Default=data.selected,Items=data.values,
                    Callback=function(v) if not option.muted and data.callback then data.callback(v) end end})
                function option:Select(v,silent) self.muted=silent; self.Raw:Set(v); self.muted=false end
                function option:SetValues(v) self.Raw:Refresh(v) end
                return option
            end
            function section:AddBind(data)
                local option=register(data,'bind')
                option.Raw=group:AddKeybind({Name=data.text,Flag=data.flag,Default=typeof(data.bind)=='EnumItem' and data.bind or nil,
                    ChangedCallback=function(v)
                        if v==Enum.KeyCode.Backspace or v==Enum.KeyCode.Escape then v=nil end
                        option.bind=v or 'none'; if data.keycallback then data.keycallback(v or 'none') end
                    end})
                function option:SetBind(v)
                    if v=='none' or v==Enum.KeyCode.Backspace or v==Enum.KeyCode.Escape then v=nil end
                    self.Raw:Set(v)
                end
                return option
            end
            function section:AddColor(data)
                local option=register(data,'color'); option.color=data.color; option.alpha=1
                option.Raw=group:AddColorPicker({Name=data.text,Flag=data.flag,Default=data.color,Alpha=1,Callback=function(v,alpha)
                    option.color,option.alpha=v,alpha
                    if data.callback then data.callback(v,1-alpha) end
                end})
                function option:SetColor(v) self.Raw:Set(v,self.alpha) end
                function option:SetTrans(v) self.Raw:Set(self.color,1-math.clamp(v,0,1)) end
                return option
            end
            function section:AddBox(data)
                local option=register(data,'box')
                option.Raw=group:AddTextbox({Name=data.text,Flag=data.flag,Default=data.input or '',Callback=data.callback})
                function option:SetInput(v) self.Raw:Set(v); if data.callback then data.callback(v) end end
                return option
            end
            function section:AddButton(data)
                local option=register(data,'button'); option.callback=data.callback
                option.Raw=group:AddButton({Name=data.text,Callback=function()
                    if data.confirm and (not option.confirmUntil or os.clock()>option.confirmUntil) then
                        option.confirmUntil=os.clock()+3; owner:SendNotification('Click again to confirm: '..data.text,3); return
                    end
                    option.confirmUntil=nil; data.callback()
                end})
                return option
            end
            function section:AddText(data)
                local option=register(data,'text'); option.Raw=group:AddLabel(data.text)
                function option:SetText(v) self.Raw.Text=v end
                return option
            end
            return section
        end
        return tab
    end
    return window
end
return UI
