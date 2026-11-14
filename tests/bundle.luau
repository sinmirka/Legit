local requests=0
Drawing=nil
getcustomasset=nil
getsynasset=nil
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
assert(app.Alive and app.Library.Gui.Name=='PlayerToolsUI','original Player Tools UI starts')
assert(requests==1,'exactly one download')
assert(#app.Library.windows[1].tabs==8,'all settings tabs retained')
assert(not SOURCES['Legit.lua']:find('files["vendor/Tokyo.lua"]',1,true),'Tokyo must not be bundled')
app:Unload()
assert(not app.DrawingRenderer.Alive and next(app.DrawingRenderer.Objects)==nil,'bundled cleanup')
local second=assert(loadstring(SOURCES['Legit.lua']))()
assert(second.Alive and requests==1,'embedded copy can execute again without any network')
second:Unload()
print('PASS README one-line loadstring: one request, original GUI, no Tokyo, no Drawing/getcustomasset and no dependency downloads')
