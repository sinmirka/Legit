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
local app=assert(loadstring(SOURCES['main.lua']))()
local esp,s=app.ObjectESP,app.Config.ObjectESP
assert(not esp:Enabled() and scans==0,'disabled does not scan world')
for _,kind in ipairs({'Scrap','GreenCrates','RedCrates','Airdrops','Dealers'}) do s[kind]=true end
esp:Step()
assert(next(esp.records)==nil and scans==0,'enabling only schedules traversal')
local function drain()
    for _=1,100 do app.WorldScanner:Step(); esp:Step() end
end
drain()
local count=0; for _ in pairs(esp.records) do count+=1 end
assert(count==5 and not esp.records[unknown] and not esp.records[fake],'canonical objects: '..count..' error='..tostring(app.WorldScanner.LastError))
assert(esp.records[green].Highlight.FillColor.G>0.8 and esp.records[red].Highlight.FillColor.R==1,'crate colours')
assert(esp.records[drop].Highlight.FillColor.R==1 and esp.records[drop].Highlight.FillColor.G>0.8,'yellow airdrop')
assert(esp.records[scrap].Label.Visible and esp.records[dealer].Label.Text:find('Dealer',1,true),'scrap and dealer labels')
s.ScrapRarity='Rare'; esp:Step(); assert(not esp.records[scrap] and esp.records[dealer],'unknown rarity hidden without affecting dealers')
scrap.Attributes={Rarity='Epic'}; esp:Step(); assert(esp.records[scrap] and esp.records[scrap].Label.Text:find('Epic',1,true),'minimum rarity includes higher ranks')
s.ScrapRarity='Legendary'; esp:Step(); assert(not esp.records[scrap],'lower rarity filtered')
scrap.Attributes.Rarity='Mythic'; esp:Step(); assert(esp.records[scrap],'live rarity changes reflected')
s.ScrapRarity='All'; scrap.Attributes=nil; esp:Step(); assert(esp.records[scrap],'All retains unknown rarity')
for _=1,100 do esp:Step() end
assert(scans==0,'no whole-world workspace rescans')
local extra=model('Crate',workspace,8,Color3.fromRGB(30,150,30))
workspace.DescendantAdded:Fire(extra); drain(); assert(esp.records[extra],'coloured unknown-named crate streamed in')
red.Parent=nil; esp:Step(); assert(not esp.records[red] and not esp.candidates[red],'removed object cleanup')
s.MaxDistance=5; esp:Step(); assert(next(esp.records)==nil,'range filter')
s.MaxDistance=1500; s.MaxObjects=2; esp:Step(); count=0; for _ in pairs(esp.records) do count+=1 end
assert(count==2,'nearest object render cap')
local old=esp.records[scrap]
for _,kind in ipairs({'Scrap','GreenCrates','RedCrates','Airdrops','Dealers'}) do s[kind]=false end
esp:Step(); assert(next(esp.records)==nil and next(esp.candidates)==nil,'disable clears all resources')
if old then assert(old.Highlight.Destroyed and old.Label.Removed,'graphics released') end
s.Scrap=true; esp:Step(); drain()
-- A broad map is processed over multiple frames, with a hard work-item limit.
for i=1,5000 do attach('Part','Scenery'..i,workspace) end
app.WorldScanner:Request(); app.WorldScanner:Step()
assert(app.WorldScanner.LastProcessed<=48 and app.WorldScanner.Scanning,'large scene work is bounded per frame')
assert(scans==0,'large scene never calls GetDescendants')
for _=1,5000 do workspace.DescendantAdded:Fire(extra) end
assert(app.WorldScanner.tail-app.WorldScanner.head<=4096,'streaming queue stays bounded')
app.WorldScanner:Step()
assert(app.WorldScanner.pending[1]==nil,'consumed streaming references are released')
app:Unload()
assert(not esp.alive and esp.folder.Destroyed and next(esp.records)==nil,'unload cleanup')
print('PASS object ESP: canonical scrap/crates/dealers, colours, streaming, range, bounded nearest rendering and cleanup')
