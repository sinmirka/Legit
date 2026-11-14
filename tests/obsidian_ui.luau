local app=assert(loadstring(SOURCES['main.lua']))()
local ui=app.Library
local names={'Aimbot','Combat','Character','ESP','Misc','Players','UI Settings'}
for index,name in ipairs(names) do assert(ui.windows[1].tabs[index].name==name,'reference tab order') end
local options=ui.options
options.ESP_Enabled.Raw:SetValue(true)
assert(app.Config.ESP.Enabled,'Obsidian toggle callback')
options.Aim_Radius.Raw:SetValue(245)
assert(app.Config.Aim.Radius==245,'Obsidian slider callback')
options.Aim_Mode.Raw:SetValue('Toggle')
assert(app.Config.Aim.Mode=='Toggle','Obsidian dropdown callback')
options.Aim_Key.Raw:SetValue({'MB1','Hold'})
assert(app.Config.Aim.Key==Enum.UserInputType.MouseButton1,'Obsidian mouse key mapping')
options.Aim_Key:SetBind(Enum.KeyCode.Backspace)
assert(app.Config.Aim.Key=='none','cleared key mapping')
options.Colors_Fill.Raw:SetValueRGB(Color3.new(0,0,0),0.6)
assert(app.Config.Colors.Fill.R==0 and math.abs(app.Config.Alpha.Colors_Fill-0.4)<1e-8,'color opacity and black')
ui:SetOpen(false); assert(not ui.open,'open state follows Obsidian')
ui.Obsidian:Toggle(true); assert(ui.open,'Obsidian hotkey state immediately visible')
local input=MOCK.services.UserInputService
local originalMouse=input.GetMouseLocation
input.GetMouseLocation=function() return MOCK.vec(210,110) end
assert(ui:IsPointerOverUI(),'pointer over main frame')
input.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1})
input.GetMouseLocation=function() return MOCK.vec(0,0) end
assert(ui:IsInteracting(),'drag remains blocked outside frame')
input.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1})
assert(not ui:IsInteracting(),'release ends interaction')
ui.Obsidian.IsPicking=true; assert(ui:IsInteracting(),'key capture blocks aim'); ui.Obsidian.IsPicking=false
input.GetMouseLocation=originalMouse
ui:SetStatus('Target: @Player2 / Head'); ui:SendNotification('Saved',4)
assert(ui.StatusLabel.Text=='Legit | Target: @Player2 / Head' and ui.Obsidian.LastNotification=='Saved','status and notification independent')
ui.Obsidian:Unload()
assert(not app.Alive and not ui.Alive and not app.DrawingRenderer.Alive,'upstream unload cleans application')
print('PASS Obsidian API contract: seven tabs, widget callbacks, keys, opacity, drag guards and upstream unload')
