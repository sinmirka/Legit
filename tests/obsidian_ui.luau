local app=assert(loadstring(SOURCES['main.lua']))()
local ui=app.Library
local names={'Aimbot','Combat','Character','ESP','World','Misc','Players','UI Settings'}
assert(ui.windows[1].Raw:GetSidebarWidth()==170,'narrow sidebar')
assert(ui.Obsidian.WindowInfo.EnableCompacting==false,'narrow sidebar retains tab names')
assert(ui.Obsidian.ToggleKeybind==nil,'upstream key handler disabled to avoid double toggles and mouse clicks')
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
input.InputBegan:Fire({KeyCode=Enum.KeyCode.RightShift,UserInputType=Enum.UserInputType.Keyboard},true)
assert(not ui.open,'processed RightShift closes menu')
input.InputBegan:Fire({KeyCode=Enum.KeyCode.RightShift,UserInputType=Enum.UserInputType.Keyboard},true)
assert(ui.open,'processed RightShift reopens menu')
local originalFocus=input.GetFocusedTextBox
local focused={IsDescendantOf=function(_,gui) return gui==ui.Gui end}
function focused:ReleaseFocus() self.Released=true end
input.GetFocusedTextBox=function() return focused end
input.InputBegan:Fire({KeyCode=Enum.KeyCode.RightShift,UserInputType=Enum.UserInputType.Keyboard},true)
assert(not ui.open and focused.Released,'RightShift closes menu while internal input has focus')
ui:SetOpen(true)
options.Interface_MenuKey:SetBind(Enum.KeyCode.Q)
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Q,UserInputType=Enum.UserInputType.Keyboard},true)
assert(ui.open,'typing with printable menu key does not toggle')
input.GetFocusedTextBox=originalFocus
ui.Obsidian.IsPicking=true
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Q,UserInputType=Enum.UserInputType.Keyboard},true)
assert(ui.open,'binding capture takes priority over menu hotkey')
ui.Obsidian.IsPicking=false
options.Interface_Scale:SetValue(85)
assert(ui.Obsidian.DPIScale==0.85,'UI scale uses Obsidian DPI')
options.Interface_MenuKey:SetBind(Enum.KeyCode.Insert)
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Insert,UserInputType=Enum.UserInputType.Keyboard},true)
assert(not ui.open,'rebound menu key')
ui:SetOpen(true)
local originalMouse=input.GetMouseLocation
input.GetMouseLocation=function() return MOCK.vec(210,110) end
assert(ui:IsPointerOverUI(),'pointer over main frame')
input.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1})
assert(ui.open,'clicking controls does not toggle menu')
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
print('PASS Obsidian API contract: eight tabs, narrow sidebar, scale, processed hotkeys, widget callbacks, opacity, drag guards and upstream unload')
