-- Contract double for Obsidian, not a renderer. Production always uses the vendored library.
-- Keep method signatures aligned with vendor/Obsidian/Library.lua.
local nativeLoadstring=loadstring
local function obsidian()
    local ob={Options={},Toggles={},Scheme={AccentColor=Color3.fromRGB(125,85,255)},
        DraggableElements={},Toggled=false,UnloadSignals={},Tabs={}}
    ob.ScreenGui=Instance.new('ScreenGui'); ob.ScreenGui.Name='Obsidian'
    function ob:OnUnload(fn) table.insert(self.UnloadSignals,fn) end
    function ob:Unload()
        if self.Unloaded then return end
        self.Unloaded=true
        for _,fn in ipairs(self.UnloadSignals) do fn() end
        self.ScreenGui:Destroy()
    end
    function ob:Toggle(value) if value==nil then value=not self.Toggled end; self.Toggled=value end
    function ob:Notify(text) self.LastNotification=text end
    function ob:UpdateColorsUsingRegistry() self.ColorUpdates=(self.ColorUpdates or 0)+1 end
    function ob:SetDPIScale(value) self.DPIScale=value/100 end
    function ob:MouseIsOverFrame(frame,point)
        local p,s=frame.AbsolutePosition,frame.AbsoluteSize
        return point.X>=p.X and point.Y>=p.Y and point.X<=p.X+s.X and point.Y<=p.Y+s.Y
    end
    function ob:AddDraggableLabel(text)
        return {Text=text,SetText=function(self,value) self.Text=value end,SetVisible=function(self,value) self.Visible=value end}
    end
    local function control(id,info,kind)
        assert(type(id)=='string' and type(info)=='table','Obsidian control signature')
        assert(info.Text or kind=='key' or kind=='color','Obsidian Text property')
        local option={Value=info.Default,Transparency=info.Transparency,Info=info,Type=kind}
        function option:SetValue(value)
            if kind=='key' then
                self.Value=value[1]
                local name=value[1]
                local key=name=='None' and nil or (name:match('^MB[123]$') and Enum.UserInputType['MouseButton'..name:sub(3)] or Enum.KeyCode[name])
                if name=='None' then key=nil end
                if info.ChangedCallback then info.ChangedCallback(key) end
            else
                self.Value=value
                if info.Callback then info.Callback(value) end
            end
        end
        function option:SetValueRGB(color,transparency)
            assert(typeof(color)=='Color3','ColorPicker RGB setter')
            self.Value,self.Transparency=color,transparency
            if info.Callback then info.Callback(color) end
        end
        function option:SetValues(values) self.Values=values end
        ob.Options[id]=option
        if kind=='toggle' then ob.Toggles[id]=option end
        return option
    end
    function ob:CreateWindow(info)
        assert(info.Title and info.Size and info.AutoShow and info.Resizable,'window options')
        self.ToggleKeybind=info.ToggleKeybind
        self.Toggled=true
        local raw={MainFrame=Instance.new('Frame')}; raw.MainFrame.Parent=self.ScreenGui; raw.MainFrame.Visible=true
        function raw:AddTab(name)
            local tab={Name=name}
            function tab:Show() ob.ActiveTab=self end
            function tab:AddGroupbox(info)
                assert(info.Name and (info.Side=='Left' or info.Side=='Right'),'groupbox options')
                local group={}
                function group:AddToggle(id,data) return control(id,data,'toggle') end
                function group:AddSlider(id,data) assert(data.Rounding~=nil); return control(id,data,'slider') end
                function group:AddDropdown(id,data) return control(id,data,'dropdown') end
                function group:AddInput(id,data) return control(id,data,'input') end
                function group:AddButton(data) assert(data.Text and data.Func); return data end
                function group:AddLabel(text)
                    local label={Text=text}
                    function label:SetText(value) self.Text=value end
                    function label:AddKeyPicker(id,data) control(id,data,'key'); return self end
                    function label:AddColorPicker(id,data) control(id,data,'color'); return self end
                    return label
                end
                return group
            end
            table.insert(ob.Tabs,tab)
            return tab
        end
        self.Window=raw
        return raw
    end
    return ob
end
function loadstring(source,name)
    if name=='@Legit/vendor/Obsidian/Library.lua' then
        return function(icons) assert(icons and icons.GetAsset,'real bundled Lucide API'); return obsidian() end
    end
    return nativeLoadstring(source,name)
end
