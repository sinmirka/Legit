-- Drawing-shaped renderer backed by Roblox GUI. Does not replace global Drawing.
local TextService=game:GetService('TextService')
local GuiDrawing={}
local fonts={[0]=Enum.Font.Arial,[1]=Enum.Font.Arial,[2]=Enum.Font.SourceSans,[3]=Enum.Font.Code}
local function instance(class,properties,parent)
    local object=Instance.new(class)
    for key,value in pairs(properties or {}) do object[key]=value end
    object.Parent=parent
    return object
end
function GuiDrawing.new(parent)
    local root=instance('ScreenGui',{
        Name='LegitGuiDrawing',IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=200,
        ZIndexBehavior=Enum.ZIndexBehavior.Global,
    },parent)
    local api={Root=root,Objects={},Alive=true}
    function api.new(class)
        assert(api.Alive,'GUI renderer is unloaded')
        assert(table.find({'Square','Text','Line','Circle','Triangle','Image'},class),'Unsupported GUI drawing '..tostring(class))
        local values={Visible=false,Color=Color3.new(1,1,1),Transparency=1,ZIndex=0,
            Position=Vector2.zero,Size=class=='Text' and 13 or Vector2.zero,
            Thickness=1,Filled=false,Text='',Font=2,Center=false,Outline=false,
            OutlineColor=Color3.new(0,0,0),Radius=0,NumSides=64,
            From=Vector2.zero,To=Vector2.zero,PointA=Vector2.zero,PointB=Vector2.zero,PointC=Vector2.zero,Data='',
        }
        local kind=class=='Text' and 'TextLabel' or class=='Image' and 'ImageLabel' or 'Frame'
        local body=instance(kind,{BackgroundTransparency=1,BorderSizePixel=0,Visible=false,Active=false},root)
        local stroke,round
        if class=='Square' or class=='Circle' or class=='Text' then
            stroke=instance('UIStroke',{},body)
            if class~='Text' then stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border end
        end
        if class=='Circle' then round=instance('UICorner',{CornerRadius=UDim.new(1,0)},body) end
        local removed=false
        local scanlines,edges={},{}
        local cachedText,cachedFont,cachedSize,cachedBounds
        local object={}
        local function bounds()
            if values.Text~=cachedText or values.Font~=cachedFont or values.Size~=cachedSize then
                cachedText,cachedFont,cachedSize=values.Text,values.Font,values.Size
                cachedBounds=TextService:GetTextSize(tostring(values.Text),math.max(1,values.Size),fonts[values.Font] or fonts[2],Vector2.new(100000,100000))
            end
            return cachedBounds
        end
        local function drawLine(frame,a,b,thickness,opacity)
            local delta=b-a
            frame.AnchorPoint=Vector2.new(0.5,0.5)
            frame.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
            frame.Size=UDim2.fromOffset(delta.Magnitude,math.max(0.5,thickness))
            frame.Rotation=math.deg(math.atan2(delta.Y,delta.X))
            frame.BackgroundColor3=values.Color
            frame.BackgroundTransparency=1-opacity
            frame.ZIndex=math.clamp(math.floor(values.ZIndex),0,10000)
        end
        local function update()
            if removed then return end
            local opacity=math.clamp(values.Transparency,0,1)
            body.Visible=values.Visible
            body.ZIndex=math.clamp(math.floor(values.ZIndex),0,10000)
            if class=='Text' then
                local size=bounds()
                body.Position=UDim2.fromOffset(values.Position.X,values.Position.Y)
                body.Size=UDim2.fromOffset(math.max(1,size.X+2),math.max(1,size.Y))
                body.AnchorPoint=Vector2.new(values.Center and 0.5 or 0,0)
                body.Font=fonts[values.Font] or fonts[2]
                body.TextSize=values.Size
                body.Text=tostring(values.Text)
                body.TextColor3=values.Color
                body.TextTransparency=1-opacity
                body.TextXAlignment=values.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
                body.TextYAlignment=Enum.TextYAlignment.Top
                stroke.Enabled=values.Outline
                stroke.Color=values.OutlineColor
                stroke.Transparency=1-opacity
                stroke.Thickness=1
            elseif class=='Line' then
                drawLine(body,values.From,values.To,values.Thickness,opacity)
            elseif class=='Triangle' then
                local points={values.PointA,values.PointB,values.PointC}
                if values.Filled then
                    for _,edge in ipairs(edges) do edge.Visible=false end
                    local minY=math.floor(math.min(points[1].Y,points[2].Y,points[3].Y))
                    local maxY=math.ceil(math.max(points[1].Y,points[2].Y,points[3].Y))
                    local step=math.max(1,(maxY-minY)/256)
                    local used=0
                    for y=minY,maxY,step do
                        local intersections={}
                        for i=1,3 do
                            local a,b=points[i],points[i%3+1]
                            if a.Y~=b.Y and y>=math.min(a.Y,b.Y) and y<math.max(a.Y,b.Y) then
                                table.insert(intersections,a.X+(y-a.Y)*(b.X-a.X)/(b.Y-a.Y))
                            end
                        end
                        if #intersections>=2 then
                            used+=1
                            scanlines[used]=scanlines[used] or instance('Frame',{BorderSizePixel=0},body)
                            local line=scanlines[used]
                            line.Visible=true
                            line.Position=UDim2.fromOffset(math.min(unpack(intersections)),y)
                            line.Size=UDim2.fromOffset(math.max(1,math.max(unpack(intersections))-math.min(unpack(intersections))),step)
                            line.BackgroundColor3=values.Color; line.BackgroundTransparency=1-opacity; line.ZIndex=body.ZIndex
                        end
                    end
                    for i=used+1,#scanlines do scanlines[i].Visible=false end
                else
                    for _,line in ipairs(scanlines) do line.Visible=false end
                    for i=1,3 do
                        edges[i]=edges[i] or instance('Frame',{BorderSizePixel=0},body)
                        edges[i].Visible=true
                        drawLine(edges[i],points[i],points[i%3+1],values.Thickness,opacity)
                    end
                end
            else
                local size=class=='Circle' and Vector2.new(values.Radius*2,values.Radius*2) or values.Size
                body.Position=UDim2.fromOffset(values.Position.X,values.Position.Y)
                body.Size=UDim2.fromOffset(math.max(0,size.X),math.max(0,size.Y))
                body.AnchorPoint=class=='Circle' and Vector2.new(0.5,0.5) or Vector2.zero
                if class=='Image' then
                    body.Image=values.Data
                    body.ImageColor3=values.Color
                    body.ImageTransparency=1-opacity
                else
                    body.BackgroundColor3=values.Color
                    body.BackgroundTransparency=values.Filled and 1-opacity or 1
                    stroke.Enabled=not values.Filled
                    stroke.Color=values.Color; stroke.Transparency=1-opacity; stroke.Thickness=math.max(0.5,values.Thickness)
                end
            end
        end
        local function remove()
            if removed then return end
            removed=true
            values.Visible=false
            api.Objects[object]=nil
            body:Destroy()
        end
        setmetatable(object,{
            __index=function(_,key)
                if key=='Remove' or key=='Destroy' then return remove end
                if key=='Removed' then return removed end
                if key=='TextBounds' and class=='Text' then return bounds() end
                return values[key]
            end,
            __newindex=function(_,key,value)
                if removed then return end
                if values[key]~=nil then values[key]=value; update() end
            end,
        })
        api.Objects[object]=true
        return object
    end
    function api:Destroy()
        if not self.Alive then return end
        self.Alive=false
        local pending={}
        for object in pairs(self.Objects) do table.insert(pending,object) end
        for _,object in ipairs(pending) do object:Remove() end
        root:Destroy()
    end
    return api
end
return GuiDrawing
