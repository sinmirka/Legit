local app=assert(loadstring(SOURCES['main.lua']))()
local ui,ir=app.Library,app.Library.Native
assert(not ui.LastRenderError,'initial Iris cycle')
local names={'Aimbot','Combat','Character','ESP','World','Misc','Players','UI Settings'}
for index,name in ipairs(names) do assert(ui.windows[1].tabs[index].name==name,'tab order') end
local options=ui.options
options.ESP_Enabled.State:set(true); assert(app.Config.ESP.Enabled,'checkbox state callback')
options.Aim_Radius.State:set(245); assert(app.Config.Aim.Radius==245,'numeric state callback')
options.Aim_Mode.State:set('Toggle'); assert(app.Config.Aim.Mode=='Toggle','combo state callback')
options.Aim_Key:SetBind(Enum.UserInputType.MouseButton1); assert(app.Config.Aim.Key==Enum.UserInputType.MouseButton1,'mouse bind')
options.Aim_Key:SetBind(Enum.KeyCode.Backspace); assert(app.Config.Aim.Key=='none','clear bind')
options.Colors_Fill:SetColor(Color3.new(0,0,0)); options.Colors_Fill:SetTrans(0.6)
assert(app.Config.Colors.Fill.R==0 and math.abs(app.Config.Alpha.Colors_Fill-0.4)<1e-8,'color transparency conversion')
local subscriptions=ir.StateSubscriptions
for _=1,100 do ui:Cycle(1/60) end
assert(ir.StateSubscriptions==subscriptions,'no callback/state subscription growth across frames')
for _,tab in ipairs(ui.windows[1].tabs) do tab:Select(); ui:Cycle(0); assert(not ui.LastRenderError,'balanced containers for '..tab.name) end
ui:SetOpen(false); assert(not ui.open,'hide state')
ui.Window:SetOpen(true); ui:Cycle(0); assert(ui.open,'show state')
local input=MOCK.services.UserInputService
ui:SetOpen(false)
input.MouseBehavior=Enum.MouseBehavior.LockCenter; input.MouseIconEnabled=false
ui:SetOpen(true)
assert(ui.modal.Modal and ui.modal.Visible and input.MouseIconEnabled,'native modal menu cursor access')
input.Down[Enum.UserInputType.MouseButton2]=true
for _=1,100 do
    input.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition
    MOCK.services.RunService.RenderStepped:Fire(1/60)
    assert(input.MouseBehavior==Enum.MouseBehavior.LockCurrentPosition,'menu never overwrites camera mouse capture')
end
input.Down[Enum.UserInputType.MouseButton2]=nil
ui:SetOpen(false)
assert(not ui.modal.Visible and input.MouseBehavior==Enum.MouseBehavior.LockCurrentPosition and not input.MouseIconEnabled,
    'closing disables modal and restores only cursor icon, preserving latest camera behavior')
ui:SetOpen(true); ui:Cycle(0)
local originalMouse=input.GetMouseLocation
input.GetMouseLocation=function() return MOCK.vec(210,110) end
assert(ui:IsPointerOverUI(),'pointer guard covers Iris window')
input.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1})
input.GetMouseLocation=function() return MOCK.vec(0,0) end
assert(ui:IsInteracting(),'drag guard beyond window')
input.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1}); assert(not ui:IsInteracting(),'drag release')
ui.windows[1].tabs[1]:Select(); ir.Clicks.Aim_Key=true; ui:Cycle(0)
assert(ui.listening==options.Aim_Key and ui:IsInteracting(),'key capture button')
local opened=ui.open
input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.RightShift})
assert(app.Config.Aim.Key==Enum.KeyCode.RightShift and not ui.listening and ui.open==opened,'capture does not toggle menu')
input.GetMouseLocation=originalMouse
ui:SetStatus('Target: @Player2 / Head'); ui:SendNotification('Saved',4)
assert(ui.Status=='Target: @Player2 / Head' and ui.LastNotification=='Saved','status and notice')
ui.windows[1].tabs[8]:Select()
local button
for _,section in ipairs(ui.windows[1].tabs[8].sections) do for _,option in ipairs(section.options) do
    if option.text=='Save profile' then button=option end
end end
local calls=0
local save=button.callback
button.callback=function() assert(not ir.InCycle,'actions execute outside Iris cycle'); calls+=1; save() end
ir.Clicks[button.id]=true; ui:Cycle(0); ui:Cycle(0)
assert(calls==1,'button action fires once, not every frame')
options.Aim_Key:SetBind('none')
ui:SetOpen(true)
local menuInput={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.RightShift}
input.InputBegan:Fire(menuInput,true); assert(not ui.open,'processed RightShift hides menu')
input.InputBegan:Fire(menuInput,true); assert(ui.open,'processed RightShift reopens menu')
local focus=input.GetFocusedTextBox
local textBox=Instance.new('TextBox'); textBox.Parent=ir.Internal._rootInstance
local released=false; function textBox:ReleaseFocus() released=true end
input.GetFocusedTextBox=function() return textBox end
input.InputBegan:Fire(menuInput,true)
assert(not ui.open and released,'RightShift closes own focused input and releases focus')
ui:SetMenuKey(Enum.KeyCode.Q); ui:SetOpen(true)
input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Q},true)
assert(ui.open,'printable custom hotkey does not interrupt typing')
input.GetFocusedTextBox=focus
input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Q},true)
assert(not ui.open,'custom menu key works outside typing')
ui:SetMenuKey('none'); ui:SetOpen(true)
input.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,KeyCode=Enum.KeyCode.Unknown},false)
assert(ui.open,'cleared menu key does not match mouse Unknown keycode')
ui:Unload()
assert(not app.Alive and not ui.Alive and ir.ShutdownCalled and not app.DrawingRenderer.Alive and not ui.modal.Visible,'Iris shutdown cleans app and modal state')
local old=app.Config.Aim.Radius; options.Aim_Radius.State:set(300)
assert(app.Config.Aim.Radius==old,'disposed state callback cannot mutate unloaded app')
print('PASS Iris adapter: eight tabs, stable states, one-shot deferred actions, binds, alpha, mouse, profiles and cleanup')
