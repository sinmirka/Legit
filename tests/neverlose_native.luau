-- Execute the real vendored widgets with engine API doubles, not the UI contract double.
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
TweenInfo={new=function() return {} end}
NumberSequence={new=function(...) return {...} end}
ColorSequence={new=function(...) return {...} end}
ColorSequenceKeypoint={new=function(...) return {...} end}
local function event() return Instance.new('BindableEvent').Activated end
local originalInstanceNew=Instance.new
local made={}
Instance.new=function(class)
    local object=originalInstanceNew(class)
    object.TextBounds=MOCK.vec(30,14)
    for _,name in ipairs({'MouseEnter','MouseLeave','MouseButton1Down','MouseButton1Up','MouseButton1Click','Focused','Changed'}) do
        object[name]=originalInstanceNew('BindableEvent').Activated
    end
    function object:GetChildren()
        local children={}; for _,item in ipairs(made) do if item.Parent==self then table.insert(children,item) end end
        return children
    end
    table.insert(made,object); return object
end
MOCK.services.TweenService={Create=function(_,object,_,properties)
    return {Play=function() for key,value in pairs(properties) do object[key]=value end end,Completed=event()}
end}
local native=assert(loadstring(SOURCES['vendor/Neverlose/Library.lua'],'@native-verification'))()
assert(#made==0,'loading the library creates no demo GUI or effects')
local window=native:CreateWindow({Title='LEGIT',Blur=0})
local tab=window:AddTab('ESP')
local group=tab:AddGroup('Settings',nil,'Left')
local value
local check=group:AddCheckbox({Name='Enabled',Default=false,Callback=function(v) value=v end})
check:Set(true); assert(value and check:Get(),'real checkbox API')
local slider=group:AddSlider({Name='Amount',Min=0,Max=1,Default=0.5,Decimals=2,Callback=function(v) value=v end})
slider:Set(0.25); assert(value==0.25,'real decimal slider API')
local dropdown=group:AddDropdown({Name='Part',Items={'Head','Torso'},Callback=function(v) value=v end})
dropdown:Set('Torso'); dropdown:Refresh({'Head'}); assert(value=='Torso','real dropdown API')
local bind=group:AddKeybind({Name='Aim key',Default=Enum.UserInputType.MouseButton2,ChangedCallback=function(v) value=v end})
bind:Set(Enum.KeyCode.Q); assert(value==Enum.KeyCode.Q and bind:Get()==value,'real keybind setter callback')
local color=group:AddColorPicker({Name='Fill',Default=Color3.new(1,1,1),Callback=function(_,alpha) value=alpha end})
color:Set(Color3.new(0,0,0),0.3); assert(value==0.3,'real alpha API')
group:AddTextbox({Name='Profile',Default='default'}):Set('new')
group:AddButton({Name='Save',Callback=function() end}); group:AddLabel('Status')
window:SetOpen(false); assert(not window.Main.Visible,'real menu hiding')
window:Destroy(); window:Destroy()
for _,signal in ipairs({MOCK.services.UserInputService.InputBegan,MOCK.services.UserInputService.InputChanged,MOCK.services.UserInputService.InputEnded}) do
    for _,entry in ipairs(signal.handlers) do assert(not entry[1].Connected,'global Neverlose input connection leaked') end
end
local contractLoader=loadstring
loadstring=function(source,name)
    if name=='@Legit/vendor/Neverlose/Library.lua' then return function() return native end end
    return contractLoader(source,name)
end
local app=assert(loadstring(SOURCES['main.lua']))()
assert(app.Alive and #app.Library.windows[1].tabs==8,'full application starts with real Neverlose widgets')
app.Library.options.ObjectESP_MaxDistance:SetValue(500)
app.Library.options.Character_Speed:SetValue(25)
assert(app.Config.ObjectESP.MaxDistance==500 and app.Config.Character.Speed==25,'real application callbacks')
app:Unload()
assert(not app.Library.Alive and app.Library.Window.Destroyed,'full application native cleanup')
print('PASS real Neverlose widgets: no demo, setters, alpha, groups, hide and global input cleanup (engine doubles, no rendering proof)')
