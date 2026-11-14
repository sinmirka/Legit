-- Real bundled Iris loading, widget registration and State API under engine doubles.
Font={fromEnum=function(value) return {__type='Font',Family=value.Name} end}
Rect={new=function(...) return {__type='Rect'} end}
MOCK.services.RunService.IsStudio=function() return false end
MOCK.services.GuiService={GetGuiInset=function() return Vector2.zero end,
    GetPropertyChangedSignal=function()
        return {Once=function() return {Disconnect=function() end} end}
    end}
local ir=assert(loadstring(SOURCES['vendor/Iris/Bundle.lua'],'@real-iris-bundle'))()
assert(ir.Internal and ir.Checkbox and ir.InputColor4 and ir.TabBar,'real modules loaded and API registered')
local calls=0
ir.PushId('native-state')
local state=ir.State(1)
ir.PopId()
local dispose=state:onChange(function(v) calls+=1; assert(v==2 or v==3,'state value') end)
state:set(2); state:set(2); assert(calls==1,'real Iris state does not repeat unchanged values')
dispose(); state:set(3); assert(calls==1,'real state disposal')
local tableWidget={_columnIndex=1,_rowIndex=1,arguments={NumColumns=2}}
ir.Internal._GetParentWidget=function() return tableWidget end
assert(ir.NextColumn()==2 and tableWidget._rowIndex==1,'real table starts in first column')
assert(ir.NextColumn()==1 and tableWidget._rowIndex==2,'real table wraps after second column')
print('PASS real Iris bundle: local module resolution, widget registration and native state callbacks (no render proof)')
