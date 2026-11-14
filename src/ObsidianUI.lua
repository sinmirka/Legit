-- Adapt application controls and engine input guards to the actual Obsidian widgets.
local Input=game:GetService('UserInputService')
local UI={}
UI.__index=function(self,key)
    if key=='open' then return self.Obsidian.Toggled end
    return UI[key]
end
local function signal()
    local handlers={}
    return {Connect=function(_,fn)
        local connection={Connected=true}
        function connection:Disconnect() self.Connected=false end
        table.insert(handlers,{connection,fn}); return connection
    end,Fire=function()
        for _,entry in ipairs(handlers) do if entry[1].Connected then entry[2]() end end
        table.clear(handlers)
    end}
end
local function keyName(key)
    if key=='none' or key==Enum.KeyCode.Backspace then return 'None' end
    for index=1,3 do if key==Enum.UserInputType['MouseButton'..index] then return 'MB'..index end end
    return key.Name
end
function UI.new(obsidian)
    local self=setmetatable({Obsidian=obsidian,Alive=true,options={},windows={},connections={},
        theme={Accent=obsidian.Scheme.AccentColor},unloaded=signal()},UI)
    self.themes={{theme=self.theme}}
    obsidian:OnUnload(function()
        if not self.Alive then return end
        self.Alive=false
        for _,connection in ipairs(self.connections) do connection:Disconnect() end
        self.unloaded:Fire()
    end)
    local function connect(event,fn) table.insert(self.connections,event:Connect(fn)) end
    connect(Input.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            self.dragging=self:IsPointerOverUI()
        end
    end)
    connect(Input.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self.dragging=false end
    end)
    connect(Input.WindowFocusReleased,function() self.dragging=false end)
    self.NewWindow=function(data) return self:CreateWindow(data) end
    return self
end
function UI:init() self.hasInit=true end
function UI:SetOpen(value) self.Obsidian:Toggle(value) end
function UI:SetTheme(theme)
    self.theme=theme; self.Obsidian.Scheme.AccentColor=theme.Accent
    self.Obsidian:UpdateColorsUsingRegistry()
end
function UI:SendNotification(message,duration) self.Obsidian:Notify(message,duration or 5) end
function UI:SetStatus(message)
    if self.Status==message then return end
    self.Status=message
    if self.StatusLabel then self.StatusLabel:SetText('Legit | '..message) end
end
function UI:IsPointerOverUI()
    if not self.Alive then return false end
    local ob=self.Obsidian
    local mouse=Input:GetMouseLocation()
    local function over(frame)
        return frame and frame.Parent and frame.Visible and ob:MouseIsOverFrame(frame,mouse)
    end
    if ob.Toggled and ob.Window and over(ob.Window.MainFrame) then return true end
    for _,frame in ipairs(ob.DraggableElements or {}) do if over(frame) then return true end end
    -- Dropdowns, color menus and key pickers can extend beyond the main frame.
    if ob.Floats then
        for _,frame in ipairs(ob.Floats:GetChildren()) do
            if frame:IsA('GuiObject') and over(frame) then return true end
        end
    end
    return false
end
function UI:IsInteracting()
    return self.dragging==true or self.Obsidian.IsPicking==true or Input:GetFocusedTextBox()~=nil
end
function UI:Unload() if self.Alive then self.Obsidian:Unload() end end
function UI:CreateWindow(data)
    local owner=self
    local raw=self.Obsidian:CreateWindow({Title=data.title,Footer='Legit | Obsidian',
        Center=true,AutoShow=true,Resizable=true,Size=data.size,ToggleKeybind=self.toggleKey,
        ShowCustomCursor=false,NotifySide='Right',UnlockMouseWhileOpen=true})
    local window={tabs={},Raw=raw}
    self.Gui=self.Obsidian.ScreenGui
    self.StatusLabel=self.Obsidian:AddDraggableLabel('Legit | Aimbot: OFF')
    self.StatusLabel:SetVisible(false)
    table.insert(self.windows,window)
    function window:AddTab(name)
        local tab={name=name,sections={},Raw=raw:AddTab(name)}
        table.insert(self.tabs,tab)
        function tab:Select() self.Raw:Show() end
        function tab:AddSection(name,side)
            local group=self.Raw:AddGroupbox({Name=name,Side=side==2 and 'Right' or 'Left'})
            local section={options={},Raw=group}
            table.insert(self.sections,section)
            local function register(data,kind)
                local option={text=data.text,class=kind}
                table.insert(section.options,option)
                if data.flag then owner.options[data.flag]=option end
                return option
            end
            function section:AddToggle(data)
                local option=register(data,'toggle')
                option.Raw=group:AddToggle(data.flag,{Text=data.text,Default=data.state,Callback=function(value)
                    option.state=value; if data.callback then data.callback(value) end
                end})
                function option:SetState(value) self.Raw:SetValue(value) end
                return option
            end
            function section:AddSlider(data)
                local option=register(data,'slider')
                local step=data.increment or 1
                local rounding=0
                while rounding<4 and math.abs(step-math.round(step))>0.00001 do rounding+=1; step*=10 end
                option.Raw=group:AddSlider(data.flag,{Text=data.text,Default=data.value,Min=data.min,Max=data.max,
                    Rounding=rounding,Suffix=data.suffix,AllowRightClickInput=true,Callback=data.callback})
                function option:SetValue(value) self.Raw:SetValue(math.clamp(value,data.min,data.max)) end
                return option
            end
            function section:AddList(data)
                local option=register(data,'list')
                option.Raw=group:AddDropdown(data.flag,{Text=data.text,Values=data.values,Default=data.selected,
                    Searchable=true,Callback=function(value)
                        if not option.muted and data.callback then data.callback(value) end
                    end})
                function option:Select(value,silent)
                    self.muted=silent; self.Raw:SetValue(value); self.muted=false
                end
                function option:SetValues(values) self.Raw:SetValues(values) end
                return option
            end
            function section:AddBind(data)
                local option=register(data,'bind')
                local label=group:AddLabel(data.text)
                label:AddKeyPicker(data.flag,{Default=keyName(data.bind),Text=data.text,Mode='Hold',Modes={'Hold'},
                    NoUI=true,ChangedCallback=function(key)
                        option.bind=key or 'none'
                        if key==Enum.KeyCode.Backspace then option:SetBind('none'); return end
                        if data.keycallback then data.keycallback(key or 'none') end
                    end})
                option.Raw=owner.Obsidian.Options[data.flag]
                function option:SetBind(key) self.Raw:SetValue({keyName(key),'Hold'}) end
                return option
            end
            function section:AddColor(data)
                local option=register(data,'color')
                local label=group:AddLabel(data.text)
                label:AddColorPicker(data.flag,{Title=data.text,Default=data.color,Transparency=0,Callback=function(value)
                    local raw=owner.Obsidian.Options[data.flag]
                    if data.callback then data.callback(value,raw and raw.Transparency or 0) end
                end})
                option.Raw=owner.Obsidian.Options[data.flag]
                function option:SetColor(value) self.Raw:SetValueRGB(value,self.Raw.Transparency or 0) end
                function option:SetTrans(value) self.Raw:SetValueRGB(self.Raw.Value,math.clamp(value,0,1)) end
                return option
            end
            function section:AddBox(data)
                local option=register(data,'box')
                option.Raw=group:AddInput(data.flag,{Text=data.text,Default=data.input or '',Finished=true,
                    ClearTextOnFocus=false,Callback=data.callback})
                function option:SetInput(value) self.Raw:SetValue(value) end
                return option
            end
            function section:AddButton(data)
                local option=register(data,'button')
                option.callback=data.callback
                option.Raw=group:AddButton({Text=data.text,Func=data.callback,DoubleClick=data.confirm==true})
                return option
            end
            function section:AddText(data)
                local option=register(data,'text')
                option.Raw=group:AddLabel(data.text,true)
                function option:SetText(text) self.Raw:SetText(text) end
                return option
            end
            return section
        end
        return tab
    end
    return window
end
return UI
