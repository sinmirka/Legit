-- Contract double for the vendored Neverlose API. Real source is compiled separately.
local nativeLoadstring=loadstring
local function neverlose()
    local native={Theme={Accent=Color3.fromRGB(76,125,255)},Icons={}}
    function native:CreateWindow()
        local gui=Instance.new('ScreenGui'); gui.Name='NeverloseUI'
        local main=Instance.new('Frame'); main.Parent=gui; main.Visible=true
        local window={Gui=gui,Main=main,Tabs={}}
        function window:SetOpen(v) main.Visible=v end
        function window:Destroy() self.Destroyed=true; gui:Destroy() end
        function window:AddTab(name)
            local tab={Name=name,Groups={}}
            function tab:Select() window.Selected=self end
            function tab:AddGroup(name,_,side)
                assert(side=='Left' or side=='Right','Neverlose side')
                local group={}; table.insert(self.Groups,group)
                local function control(data,kind)
                    assert(data.Name,'Neverlose control Name')
                    local option={Value=data.Default,Alpha=data.Alpha or 1,Data=data}
                    function option:Set(value,alpha)
                        self.Value=value
                        if kind=='color' then self.Alpha=alpha or self.Alpha end
                        if kind=='key' then if data.ChangedCallback then data.ChangedCallback(value) end
                        elseif kind~='input' and data.Callback then data.Callback(value,self.Alpha) end
                    end
                    function option:Get() return self.Value,self.Alpha end
                    function option:Refresh(values) self.Items=values end
                    return option
                end
                function group:AddCheckbox(data) return control(data,'toggle') end
                function group:AddSlider(data) assert(data.Decimals~=nil); return control(data,'slider') end
                function group:AddDropdown(data) assert(data.Items); return control(data,'list') end
                function group:AddKeybind(data) return control(data,'key') end
                function group:AddColorPicker(data) return control(data,'color') end
                function group:AddTextbox(data) return control(data,'input') end
                function group:AddButton(data) return data end
                function group:AddLabel(text) return {Text=text} end
                return group
            end
            table.insert(self.Tabs,tab); return tab
        end
        return window
    end
    return native
end
function loadstring(source,name)
    if name=='@Legit/vendor/Neverlose/Library.lua' then return neverlose end
    return nativeLoadstring(source,name)
end
