-- Run in the executor to inspect capabilities without hooks, attacks or remote calls.
local rows={'Legit runtime probe'}
for _,name in ipairs({'hookmetamethod','getnamecallmethod','checkcaller','getcallingscript','newcclosure','writefile','readfile'}) do
    table.insert(rows,name..'='..type(getfenv()[name]))
end
local app=getgenv().Legit
table.insert(rows,'Legit='..tostring(app~=nil))
if app and app.MeleeAura then table.insert(rows,'MeleeStatus='..tostring(app.MeleeAura.Status)) end
local character=game:GetService('Players').LocalPlayer.Character
local tool=character and character:FindFirstChildOfClass('Tool')
table.insert(rows,'Tool='..(tool and tool.Name or 'none'))
if tool then
    for _,child in ipairs(tool:GetChildren()) do table.insert(rows,'ToolChild='..child.Name..' ('..child.ClassName..')') end
end
local report=table.concat(rows,'\n')
writefile('Legit-runtime-probe.txt',report)
print(report)
