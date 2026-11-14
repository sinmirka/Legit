-- Iris immediate-mode API contract double. Source modules are compiled separately.
local nativeLoadstring=loadstring
local function iris()
    local ir={Args={Window={NoCollapse=4}},TemplateConfig={},States={},Widgets={},Clicks={},Config={},Functions={},NextState=0,Stack={},StateSubscriptions=0}
    local pushed={}
    local function eventFrame(name,parent)
        local frame=Instance.new('Frame'); frame.Name=name; frame.Parent=parent; frame.Visible=true; return frame
    end
    function ir.PushId(id) table.insert(pushed,id) end
    function ir.PopId() assert(#pushed>0); table.remove(pushed) end
    function ir.SetNextWidgetID(id) ir.NextID=id end
    function ir.State(value)
        local id=table.concat(pushed,'/')
        if ir.States[id] then return ir.States[id] end
        local state={value=value,ConnectedFunctions={}}
        function state:set(v,force)
            if self.value==v and not force then return v end
            self.value=v
            for _,fn in pairs(self.ConnectedFunctions) do fn(v) end
            return v
        end
        function state:onChange(fn)
            ir.StateSubscriptions+=1
            local index=#self.ConnectedFunctions+1; self.ConnectedFunctions[index]=fn
            return function() self.ConnectedFunctions[index]=nil end
        end
        ir.States[id]=state; return state
    end
    function ir.UpdateGlobalConfig(config) for key,value in pairs(config) do ir.Config[key]=value end end
    ir.Internal={_rootInstance=Instance.new('Folder')}
    function ir.Init(parent,event)
        assert(event==false,'adapter owns cycle driver')
        ir.Initialized=true; ir.Internal._rootInstance.Parent=parent
    end
    function ir:Connect(fn)
        table.insert(self.Functions,fn); local index=#self.Functions
        return function() self.Functions[index]=nil end
    end
    function ir.Internal._cycle()
        ir.InCycle=true; ir.NextID=nil; ir.Auto=0; ir.Stack={}
        for _,fn in pairs(ir.Functions) do fn() end
        assert(#ir.Stack==0,'unbalanced Iris.End calls'); assert(#pushed==0,'unbalanced Iris.PopId calls')
        ir.InCycle=false
    end
    local function widget(kind,args,states,children)
        ir.Auto=(ir.Auto or 0)+1
        local id=ir.NextID or ('auto'..ir.Auto); ir.NextID=nil
        local result={arguments=args,state=states or {},type=kind}
        function result.clicked() local clicked=ir.Clicks[id]; ir.Clicks[id]=nil; return clicked==true end
        result.Instance=eventFrame(kind,ir.Internal._rootInstance)
        if kind=='Window' then
            local main=eventFrame('WindowButton',result.Instance); result.Instance.Children.WindowButton=main
        end
        ir.Widgets[id]=result
        if children then table.insert(ir.Stack,kind) end
        return result
    end
    for _,kind in ipairs({'Window','TabBar','Tab','Table','Group','CollapsingHeader'}) do
        ir[kind]=function(args,states) return widget(kind,args,states,true) end
    end
    for _,kind in ipairs({'Checkbox','SliderNum','ComboArray','InputColor4','InputText','TextWrapped','Button'}) do
        ir[kind]=function(args,states) return widget(kind,args,states,false) end
    end
    function ir.End() assert(#ir.Stack>0,'too many Iris.End calls'); table.remove(ir.Stack) end
    function ir.NextColumn() assert(ir.Stack[#ir.Stack]=='Table','NextColumn outside Table') end
    function ir.Shutdown() ir.ShutdownCalled=true; ir.Internal._rootInstance:Destroy() end
    return ir
end
function loadstring(source,name)
    if name=='@Legit/vendor/Iris/Bundle.lua' then return iris end
    return nativeLoadstring(source,name)
end
