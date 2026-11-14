-- Exercise real Iris instances/layout under engine doubles. This is not visual QA.
local objects={}
local oldNew=Instance.new
local oldIsA=MOCK.object.IsA
MOCK.object.IsA=function(self,name)
    return (name=='BasePlayerGui' and self.ClassName=='PlayerGui') or oldIsA(self,name)
end
local function event()
    local result=oldNew('BindableEvent').Activated
    function result:Once(fn)
        local connection
        connection=self:Connect(function(...) connection:Disconnect(); fn(...) end)
        return connection
    end
    return result
end
local guiClasses={Frame=true,TextButton=true,TextLabel=true,TextBox=true,ScrollingFrame=true,ImageLabel=true,ImageButton=true,CanvasGroup=true}
Instance.new=function(class)
    local object=oldNew(class); local methods=getmetatable(object).__index
    object.Visible=true; object.Enabled=true; object.Name=class
    object.AbsoluteCanvasSize=MOCK.vec(600,400); object.TextBounds=MOCK.vec(50,15); object.Text=''
    object.AbsoluteContentSize=MOCK.vec(200,100)
    object.CanvasPosition=Vector2.zero; object.BackgroundTransparency=0; object.BorderSizePixel=0
    object.AbsolutePosition=MOCK.vec(80,70); object.AbsoluteSize=MOCK.vec(880,660)
    local events={}
    for _,name in ipairs({'MouseEnter','MouseLeave','MouseButton1Click','MouseButton2Click','MouseButton1Down','MouseButton1Up','TouchTap','Focused','Changed'}) do events[name]=event() end
    setmetatable(object,{__index=function(self,key)
        if methods[key] then return methods[key] end
        if events[key] then return events[key] end
        for _,child in ipairs(objects) do if rawget(child,'Parent')==self and rawget(child,'Name')==key then return child end end
    end})
    function object:GetChildren()
        local result={}; for _,child in ipairs(objects) do if rawget(child,'Parent')==self then table.insert(result,child) end end; return result
    end
    function object:GetDescendants()
        local result={}
        local function visit(parent) for _,child in ipairs(parent:GetChildren()) do table.insert(result,child); visit(child) end end
        visit(self); return result
    end
    function object:FindFirstChild(name)
        for _,child in ipairs(self:GetChildren()) do if child.Name==name then return child end end
    end
    function object:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
    function object:IsA(name) return name==class or name=='Instance' or (name=='GuiObject' and guiClasses[class]) end
    function object:GetPropertyChangedSignal() return event() end
    function object:IsFocused() return false end
    function object:CaptureFocus() end
    function object:ReleaseFocus() end
    function object:Destroy()
        for _,child in ipairs(self:GetChildren()) do child:Destroy() end
        self.Parent=nil; self.Destroyed=true
    end
    table.insert(objects,object); return object
end
local oldVec2=Vector2.new
Vector2.new=function(x,y) return oldVec2(x or 0,y or 0) end
Vector2.xAxis=Vector2.new(1,0); Vector2.yAxis=Vector2.new(0,1); Vector2.one=Vector2.new(1,1)
local vectorMeta=getmetatable(Vector2.zero)
vectorMeta.__unm=function(v) return MOCK.vec(-v.X,-v.Y,v.Z and -v.Z) end
local udimMeta={}
UDim.new=function(scale,offset) return setmetatable({Scale=scale or 0,Offset=offset or 0},udimMeta) end
udimMeta.__add=function(a,b) return UDim.new(a.Scale+b.Scale,a.Offset+b.Offset) end
udimMeta.__sub=function(a,b) return UDim.new(a.Scale-b.Scale,a.Offset-b.Offset) end
udimMeta.__mul=function(a,b) if type(a)=='number' then a,b=b,a end; return UDim.new(a.Scale*b,a.Offset*b) end
local oldDim=UDim2.new
UDim2.new=function(a,b,c,d)
    if type(a)=='table' then b=b or UDim.new(); return oldDim(a.Scale,a.Offset,b.Scale,b.Offset) end
    return oldDim(a or 0,b or 0,c or 0,d or 0)
end
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
Font={fromEnum=function(value) return {__type='Font',Family=value.Name} end}
Rect={new=function() return {__type='Rect'} end}
NumberSequence={new=function(...) return {...} end}
NumberSequenceKeypoint={new=function(...) return {...} end}
ColorSequence={new=function(...) return {...} end}
ColorSequenceKeypoint={new=function(...) return {...} end}
GetTextBoundsParams={new=function() return {} end}
debug=table.clone(debug); debug.profilebegin=function() end; debug.profileend=function() end
MOCK.services.RunService.IsStudio=function() return false end
MOCK.services.GuiService={GetGuiInset=function() return Vector2.zero end,GetPropertyChangedSignal=event,Select=function() end}
MOCK.services.TextService.GetTextBoundsAsync=function(_,params) return Vector2.new(math.min(400,#(params.Text or '')*7),15) end
for _,name in ipairs({'TouchStarted','TouchEnded','TouchMoved','TouchTapInWorld','TouchTap','MouseIconEnabledChanged'}) do MOCK.services.UserInputService[name]=event() end
local real=assert(loadstring(SOURCES['vendor/Iris/Bundle.lua'],'@real-iris-render'))()
local oldLoader=loadstring
loadstring=function(source,name)
    if name=='@Legit/vendor/Iris/Bundle.lua' then return function() return real end end
    return oldLoader(source,name)
end
local app=assert(loadstring(SOURCES['main.lua']))()
assert(not app.Library.LastRenderError,app.Library.LastRenderError)
for _,tab in ipairs(app.Library.windows[1].tabs) do
    tab:Select(); app.Library:Cycle(1/60); app.Library:Cycle(1/60)
    assert(not app.Library.LastRenderError,tab.name..': '..tostring(app.Library.LastRenderError))
end
app.Library.options.Interface_Accent:SetColor(Color3.fromRGB(100,180,240))
app.Library.options.Interface_Scale:SetValue(110)
app.Library:Cycle(1/60); app.Library:Cycle(1/60)
assert(not app.Library.LastRenderError,app.Library.LastRenderError)
local instances=#objects
for _=1,50 do app.Library:Cycle(1/60) end
assert(#objects==instances,'real Iris reuses instances across unchanged frames')
app.Library:SetOpen(false); app.Library:Cycle(1/60); app.Library:Cycle(1/60)
app.Library:SetOpen(true); app.Library:Cycle(1/60); app.Library:Cycle(1/60)
assert(not app.Library.LastRenderError,app.Library.LastRenderError)
local menuInput={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.RightShift}
MOCK.services.UserInputService.InputBegan:Fire(menuInput,true); app.Library:Cycle(1/60)
assert(not app.Library.open and not app.Library.windowWidget.Instance.Enabled and not app.Library.modal.Visible,'processed hotkey hides real Iris window and modal')
MOCK.services.UserInputService.InputBegan:Fire(menuInput,true); app.Library:Cycle(1/60)
assert(app.Library.open and app.Library.windowWidget.Instance.Enabled and app.Library.modal.Visible,'processed hotkey restores real Iris window and modal')
app:Unload()
assert(real.Internal._shutdown and not app.Alive,'real render shutdown')
print('PASS real Iris application cycles across all tabs using engine doubles (not visual rendering)')
