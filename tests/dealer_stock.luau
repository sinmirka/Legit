local nodes={}
local function attach(class,name,parent)
    local object=Instance.new(class); object.Name=name; object.Parent=parent
    if parent.Children then parent.Children[name]=object end
    table.insert(nodes,object); return object
end
MOCK.object.IsDescendantOf=function(object,parent)
    local current=object.Parent
    for _=1,64 do if current==parent then return true end; if not current then return false end; current=current.Parent end
    return false
end
MOCK.object.FindFirstChildWhichIsA=function(object,class,recursive)
    for _,child in pairs(object.Children) do
        if child:IsA(class) then return child end
        if recursive then local found=child:FindFirstChildWhichIsA(class,true); if found then return found end end
    end
end
workspace.Children={}
local scans=0
workspace.GetDescendants=function() scans+=1; error('whole-world scan is forbidden') end
workspace.GetChildren=MOCK.object.GetChildren
workspace.DescendantAdded=Instance.new('BindableEvent').Activated
local character=attach('Model','Local',workspace)
local root=attach('Part','HumanoidRootPart',character); root.Position=MOCK.vec(0,0,0)
MOCK.players.LocalPlayer.Character=character
local filter=attach('Folder','Filter',workspace)
local piles=attach('Folder','SpawnedPiles',filter)
local function model(name,parent,x,color)
    local m=attach('Model',name,parent)
    local part=attach('Part','Body',m); part.Position=MOCK.vec(x,0,30); part.Color=color or Color3.fromRGB(120,120,120)
    m.PrimaryPart=part; return m,part
end
local scrap=model('Pile',piles,1)
local green=model('GreenCrate',workspace,2)
local red=model('RedCrate',workspace,3)
local drop=model('Airdrop',workspace,4)
local dealer=model('ArmoryDealer',workspace,5)
local unknown=model('Crate',workspace,6)
local chars=attach('Folder','Characters',workspace)
local fake=model('RedCrate',chars,7)

local ammo=attach('IntValue','AKS-74U',dealer); ammo.Value=3
local price=attach('IntValue','M4A1',dealer); price.Value=0
local noise=attach('IntValue','AKS-74U',workspace); noise.Value=999
local app=assert(loadstring(SOURCES['main.lua']))()
local stock,s=app.DealerStock,app.Config.DealerStock
local notifications={}; app.Library.SendNotification=function(_,text) table.insert(notifications,text) end
assert(not s.Enabled and #stock.entries==0,'disabled reads nothing')
s.Enabled=true; stock:Step(); assert(#stock.entries==0 and scans==0,'enabling schedules shared scan')
local function drain() for _=1,100 do app.WorldScanner:Step(); stock:Step() end end
drain()
assert(#notifications==0,'initial asynchronous discovery is a silent baseline')
assert(stock.Text:find('AKS-74U: 3',1,true) and stock.Text:find('M4A1: 0',1,true),'snapshot reads actual dealer values')
assert(not stock.Text:find('999',1,true),'nondealer values excluded')
ammo.Value=5; stock:Step(); assert(#notifications==1 and notifications[1]:find('AKS-74U: 5',1,true),'changed stock notifies once')
stock:Step(); assert(#notifications==1,'unchanged value does not spam')
s.Notify=false; ammo.Value=6; stock:Step(); assert(#notifications==1,'notification switch')
app.Library.options.DealerStock_Items:SetInput('m4'); stock:Step()
assert(stock.Text:find('M4A1: 0',1,true) and not stock.Text:find('AKS',1,true),'item filter is case insensitive')
app.Library.options.DealerStock_Items:SetInput('AKS, M4'); stock:Step()
assert(stock.Text:find('AKS',1,true) and stock.Text:find('M4',1,true),'comma separated filters')
local streamed=attach('IntValue','M4A1 spare',dealer); streamed.Value=2
workspace.DescendantAdded:Fire(streamed); drain(); assert(stock.Text:find('M4A1 spare: 2',1,true),'streamed stock discovered')
streamed.Parent=nil; stock:Step(); assert(not stock.Text:find('spare',1,true),'removed values disappear')
assert(scans==0,'no synchronous full-world scans')
s.Enabled=false; stock:Step(); assert(#stock.entries==0 and stock.Status=='Disabled','disable clears cache')
s.Enabled=true; stock:Step(); drain(); assert(stock.Text:find('AKS',1,true),'reenable repopulates cache')
app:Unload(); assert(not stock.alive and not stock.subscription.Connected,'unload disconnects')
print('PASS dealer stock: incremental discovery, item filters, changes, no spam, streaming, disable and cleanup')
