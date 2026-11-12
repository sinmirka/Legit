local requests=0
function identifyexecutor() return 'Xeno','test' end
function getcustomasset(path)
    assert(MOCK.files[path] and MOCK.files[path]:sub(1,8)=='\137PNG\r\n\26\n','asset PNG missing')
    return 'rbxasset://mock/'..path
end
Drawing.new=function() error('Xeno must use GUI renderer') end
request=function() error('Bundle must not download modules or assets') end
http_request=request
game.HttpGet=function(_,url)
    requests+=1
    assert(requests==1,'More than one HTTP request')
    assert(url=='https://raw.githubusercontent.com/sinmirka/Legit/main/Legit.lua','Wrong README entry point')
    return SOURCES['Legit.lua']
end
assert(loadstring(SOURCES.README_BOOTSTRAP))()
local app=assert(getgenv().Legit,'README launcher must create the application')
assert(app.Alive and app.Renderer=='GUI','single-line README launcher starts the bundled Xeno application')
assert(requests==1,'exactly one download')
assert(#app.Library.windows[1].tabs==7,'Tokyo UI preserved')
local names={['gradient90.png']='gradientp90',['gradient45.png']='gradientp45',['hue.png']='colorhue',
    ['transparency.png']='colortrans',['saturationBlack.png']='saturationBlack',['saturationWhite.png']='saturationWhite'}
local expected=assert(loadstring(SOURCES.ASSET_EXPECTATIONS))()
for name,metadata in pairs(expected) do
    local data=assert(MOCK.files['Legit/assets/'..assert(names[name])..'.oh'])
    assert(#data==metadata.Size,'PNG size '..name)
    local low,high=1,0
    for i=1,#data do low=(low+data:byte(i))%65521; high=(high+low)%65521 end
    assert(high*65536+low==metadata.Checksum,'PNG bytes '..name)
end
app:Unload()
assert(not app.DrawingRenderer.Alive and next(app.DrawingRenderer.Objects)==nil,'bundled cleanup')
local second=assert(loadstring(SOURCES['Legit.lua']))()
assert(second.Alive and requests==1,'embedded copy can execute again without any network')
second:Unload()
print('PASS README one-line loadstring: exactly one HTTP request, full Tokyo UI, byte-exact embedded PNG assets and repeat execution without downloads')
