local app=assert(loadstring(SOURCES['main.lua']))()
local ui=app.Library
local names={'Aimbot','Combat','Character','ESP','World','Misc','Players','UI Settings'}
for index,name in ipairs(names) do assert(ui.windows[1].tabs[index].name==name,'reference tab order') end
local options=ui.options
options.ESP_Enabled.Raw:Set(true)
assert(app.Config.ESP.Enabled,'Neverlose toggle callback')
options.Aim_Radius.Raw:Set(245)
assert(app.Config.Aim.Radius==245,'Neverlose slider callback')
options.Aim_Mode.Raw:Set('Toggle')
assert(app.Config.Aim.Mode=='Toggle','Neverlose dropdown callback')
options.Aim_Key.Raw:Set(Enum.UserInputType.MouseButton1)
assert(app.Config.Aim.Key==Enum.UserInputType.MouseButton1,'Neverlose mouse key mapping')
options.Aim_Key:SetBind(Enum.KeyCode.Backspace)
assert(app.Config.Aim.Key=='none','cleared key mapping')
options.Colors_Fill.Raw:Set(Color3.new(0,0,0),0.4)
assert(app.Config.Colors.Fill.R==0 and math.abs(app.Config.Alpha.Colors_Fill-0.4)<1e-8,'color opacity and black')
ui:SetOpen(false); assert(not ui.open,'open state follows Neverlose')
ui.Window:SetOpen(true); assert(ui.open,'Neverlose hotkey state immediately visible')
local input=MOCK.services.UserInputService
local originalMouse=input.GetMouseLocation
input.GetMouseLocation=function() return MOCK.vec(210,110) end
assert(ui:IsPointerOverUI(),'pointer over main frame')
input.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1})
input.GetMouseLocation=function() return MOCK.vec(0,0) end
assert(ui:IsInteracting(),'drag remains blocked outside frame')
input.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1})
assert(not ui:IsInteracting(),'release ends interaction')
ui.Native.IsPicking=true; assert(ui:IsInteracting(),'key capture blocks aim'); ui.Native.IsPicking=false
input.GetMouseLocation=originalMouse
ui:SetStatus('Target: @Player2 / Head'); ui:SendNotification('Saved',4)
assert(ui.Status=='Target: @Player2 / Head' and ui.LastNotification=='Saved','status and notification independent')
ui:Unload()
assert(not app.Alive and not ui.Alive and not app.DrawingRenderer.Alive,'upstream unload cleans application')
print('PASS Neverlose API contract: eight tabs, widget callbacks, keys, opacity, drag guards and upstream unload')
