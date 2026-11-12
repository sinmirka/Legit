-- Exercise actual Tokyo with a broken native Drawing API, not a fake Tokyo UI.
function identifyexecutor() return 'Xeno','test' end
function getcustomasset(path)
    assert(MOCK.files[path] and MOCK.files[path]:sub(1,8)=='\137PNG\r\n\26\n','asset must exist before registering')
    return 'rbxasset://mock/'..path
end
local native=Drawing.new
local nativeCalls=0
Drawing.new=function() nativeCalls+=1; error('native Xeno Drawing must not be used') end
local app=assert(loadstring(SOURCES['main.lua']))()
assert(app.Alive and app.Renderer=='GUI','automatic Xeno backend selection')
assert(nativeCalls==0,'native Drawing API was used')
local renderer=app.DrawingRenderer
assert(renderer.Alive and next(renderer.Objects),'Tokyo must create GUI-backed objects')
assert(#app.Library.windows[1].tabs==7,'keep the real Tokyo interface')
for _,tab in ipairs(app.Library.windows[1].tabs) do tab:Select() end
app.Library.options.Colors_Fill:SetColor(Color3.fromRGB(40,80,120))
app.Library.options.Colors_Fill:SetTrans(0.4)
assert(app.Config.Alpha.Colors_Fill==0.6,'color callbacks in GUI mode')
local circle=renderer.new('Circle'); circle.Radius=80; circle.Visible=true; circle.Filled=false
local line=renderer.new('Line'); line.From=Vector2.new(10,10); line.To=Vector2.new(50,30); line.Thickness=2
local text=renderer.new('Text'); text.Text='Test\nLabel'; text.Size=13
assert(text.TextBounds.X>0 and text.TextBounds.Y>13,'GUI text measurement')
local triangle=renderer.new('Triangle')
triangle.PointA=Vector2.new(10,10); triangle.PointB=Vector2.new(26,15); triangle.PointC=Vector2.new(18,30); triangle.Filled=true
triangle:Remove(); triangle:Remove()
app:Unload()
assert(not renderer.Alive and renderer.Root.Destroyed and next(renderer.Objects)==nil,'GUI backend cleanup')
for _,thread in ipairs(task.pending) do
    if coroutine.status(thread)=='suspended' then local ok,problem=coroutine.resume(thread); assert(ok,problem) end
end
table.clear(task.pending)
local second=assert(loadstring(SOURCES['main.lua']))()
local third=assert(loadstring(SOURCES['main.lua']))()
assert(not second.Alive and third.Alive,'repeat Xeno execution')
third:Unload()
assert(nativeCalls==0,'native Drawing called during GUI cleanup')
identifyexecutor=function() return 'Unidentified executor' end
local forced=assert(loadstring(SOURCES['loader-xeno.lua']))()
assert(forced.Renderer=='GUI','dedicated Xeno launcher forces GUI even when executor identification is unavailable')
forced:Unload()
print('PASS automatic Xeno GUI backend, real Tokyo tabs, colors, all primitive types, text measurement, unload and repeat execution')

-- A failure during initialization must survive cleanup even if native Remove fails.
getgenv().LegitRenderer='Native'
Drawing.new=function(class)
    local object=native(class)
    function object:Remove() error("attempt to index number with 'Remove'") end
    return object
end
local previousEngine=SOURCES['src/Engine.lua']
SOURCES['src/Engine.lua']='error("INITIALIZATION_ROOT_CAUSE")'
local ok,reason=pcall(assert(loadstring(SOURCES['main.lua'])))
assert(not ok and tostring(reason):find('INITIALIZATION_ROOT_CAUSE',1,true),'cleanup must not mask initial failure')
assert(not getgenv().Legit and not getgenv().library,'globals cleared on failed startup')
for _,object in ipairs(DRAWINGS) do assert(not object.Visible,'failed native Remove should at least hide owned drawings') end
SOURCES['src/Engine.lua']=previousEngine
getgenv().LegitRenderer=nil
print('PASS original startup error preserved despite failing native Remove')
