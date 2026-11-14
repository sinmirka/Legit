-- Read-only game inspection. Exports local client code/metadata; no hooks or remote calls.
-- Equip the failing gun before running this once in the executor.
assert(type(writefile)=='function' and type(makefolder)=='function','File API required')
local root='Legit/Universal/probes/gun-pipeline'
for _,path in ipairs({'Legit','Legit/Universal','Legit/Universal/probes',root}) do
    if type(isfolder)~='function' or not isfolder(path) then
        local ok,problem=pcall(makefolder,path)
        if not ok and not (type(isfolder)=='function' and isfolder(path)) then error(problem) end
    end
end
local rows={'Legit gun pipeline probe v2','PlaceId='..tostring(game.PlaceId)}
for _,name in ipairs({'decompile','hookfunction','hookmetamethod','getnamecallmethod','checkcaller','getcallingscript'}) do
    table.insert(rows,name..'='..type(getfenv()[name]))
end
local function note(text) table.insert(rows,text) end
local function pathFrom(object,names)
    for _,name in ipairs(names) do object=object and object:FindFirstChild(name) end
    return object
end
local count=0
local function inspect(script,label)
    if not script then note(label..': missing'); return end
    note(label..': '..script:GetFullName()..' ['..script.ClassName..']')
    if type(decompile)~='function' then note(label..': decompile unavailable'); return end
    if not (script:IsA('LocalScript') or script:IsA('ModuleScript')) then return end
    local ok,source=pcall(decompile,script)
    if not ok or type(source)~='string' or not source:find('%S') then
        note(label..': decompile failed: '..tostring(source):sub(1,400)); return
    end
    local filename=label:gsub('[^%w_%-]','_')..'.lua'
    -- Fixed candidate set, bounded output. Files remain in the executor workspace.
    source=source:sub(1,1024*1024)
    writefile(root..'/'..filename,source)
    count+=1; note(label..': exported '..filename..' ('..#source..' bytes)')
end
local storage=game:GetService('ReplicatedStorage')
inspect(pathFrom(storage,{'NewModules','Shared','Extensions','LoadGun'}),'extension-LoadGun')
for _,name in ipairs({'RayHandler','FastCastRedux'}) do
    inspect(pathFrom(storage,{'NewModules','Shared','Services',name}),'service-'..name)
end
local character=game:GetService('Players').LocalPlayer.Character
local equipped=character and character:FindFirstChildOfClass('Tool')
inspect(equipped and equipped:FindFirstChild('Gun'),'gun-Gun')
local tool=character and character:FindFirstChildOfClass('Tool')
note('EquippedTool='..(tool and tool.Name or 'none; equip the failing gun and rerun'))
if tool then
    local children=tool:GetChildren()
    for index=1,math.min(#children,100) do
        local child=children[index]
        note('ToolChild='..child.Name..' ['..child.ClassName..']')
    end
    for _,name in ipairs({'Client','PassClient','Config','PassConfig'}) do inspect(tool:FindFirstChild(name),'gun-'..name) end
    local values=tool:FindFirstChild('Values')
    if values then
        for _,name in ipairs({'SERVER_Ammo','Ammo','StoredAmmo'}) do
            local value=values:FindFirstChild(name)
            if value then note('AmmoMarker='..name..' ['..value.ClassName..']') end
        end
    end
end
for _,name in ipairs({'Events','Events2'}) do
    local folder=storage:FindFirstChild(name)
    if folder then
        for _,child in ipairs(folder:GetChildren()) do note(name..'/'..child.Name..' ['..child.ClassName..']') end
    end
end
local app=getgenv().Legit
if app and app.Logger and app.DebugContext then
    local ok,report=pcall(function() return app.Logger:Report(app:DebugContext()) end)
    if ok then writefile(root..'/legit-report.txt',report) else note('Report export failed: '..tostring(report)) end
end
note('ExportedScripts='..count)
local report=table.concat(rows,'\n')..'\n'
writefile(root..'/manifest.txt',report)
print(report)
print('Saved locally to '..root..'/manifest.txt; no game remotes invoked.')
