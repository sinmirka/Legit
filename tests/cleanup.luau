local app=assert(loadstring(SOURCES['main.lua']))()
local options=app.Library.options
for _,name in ipairs({'Aim_AcquireDelay','Aim_SwitchDelay','Aim_SkipScriptable','Aim_Axis','Aim_OffsetX','Aim_OffsetY','Aim_OffsetZ',
    'Aim_ShowDeadzone','Aim_TargetLine','Aim_TargetColor','Aim_FOVOpacity','Aim_FOVThickness','Silent_AutoFireMethod',
    'Silent_ShowOriginalRay','Silent_ShowTargetGuide','Silent_TraceDuration','Silent_TraceWidth','Silent_FOVOpacity',
    'Melee_SwingWindow','Character_SpinPitch','World_BloomSize','World_BloomThreshold','World_Brightness','World_Contrast',
    'World_Saturation','World_Haze','ESP_VisibleColors','ESP_TeamColors','ESP_TargetColor','ESP_RefreshRate','Colors_VisibleFill',
    'Colors_VisibleOutline','Colors_HiddenFill','Colors_HiddenOutline','Colors_Target','ObjectESP_MaxObjects','ObjectESP_Highlight',
    'ObjectESP_Labels','ObjectESP_Distance','ObjectESP_ThroughWalls','ObjectESP_FillTransparency','Debug_Enabled','Debug_Console','Debug_CaptureRays'}) do
    assert(not options[name],'removed clutter: '..name)
end
for _,name in ipairs({'Aim_Enabled','Silent_Enabled','Melee_Enabled','Combat_WallBang','Character_Spinbot','Character_JumpCooldown',
    'Character_InfiniteStamina','World_TimeEnabled','World_BloomEnabled','World_ColorEnabled','World_AtmosphereEnabled',
    'Labels_Tool','ObjectESP_ScrapRarity','DealerStock_Enabled','Projectiles_C4','Projectiles_Rockets','Fun_Jerk'}) do
    assert(options[name],'core feature retained: '..name)
end
local function button(label)
    for _,tab in ipairs(app.Library.windows[1].tabs) do for _,section in ipairs(tab.sections) do
        for _,item in ipairs(section.options) do if item.class=='button' and item.text==label then return item end end
    end end
end
assert(button('Show combat status') and button('Start debug capture') and not button('Start melee capture') and not button('Start silent capture'),'one diagnostics block')
MOCK.files['Legit/Universal/configs/default.json']=MOCK.services.HttpService:JSONEncode({version=1,settings={
    Aim_OffsetX=100,Aim_TargetLine=true,ESP_VisibleColors=true,ObjectESP_Labels=false,Debug_Enabled=true,
    World_BloomSize=999,Character_SpinPitch=999,Labels_Tool=true}})
button('Load profile').callback()
assert(app.Config.Aim.OffsetX==0 and not app.Config.Aim.TargetLine and app.Config.ESP.VisibleColors==nil
    and app.Config.ObjectESP.Labels and not app.Config.Debug.Enabled and app.Config.World.BloomSize==24
    and app.Config.Character.SpinPitch==70,'old profiles cannot restore removed options')
app:Unload()
print('PASS compact UI: 44 removed settings, core functions retained, unified diagnostics and legacy profile defaults')
