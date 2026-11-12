local nativeCompiler=loadstring
local nilCompiles=0
function loadstring(source,...)
    if type(source)~='string' then nilCompiles+=1 end
    return nativeCompiler(source,...)
end
local download=assert(loadstring(SOURCES.HTTP_TRANSPORT))()
local originalGet=game.HttpGet
game.HttpGet=function() return nil end
local ok,message=pcall(download,'main.lua')
assert(not ok and tostring(message):find('expected response text, got nil',1,true),'nil HTTP response diagnostics')
assert(nilCompiles==0,'nil must not reach compiler')
request=function(options) return {StatusCode=200,Body=originalGet(game,options.Url)} end
assert(download('main.lua')==SOURCES['main.lua'],'request bypasses broken HttpGet')
request=nil
http_request=function(options) return {StatusCode=200,Body=originalGet(game,options.Url)} end
assert(download('main.lua')==SOURCES['main.lua'],'http_request alias')
http_request=nil
request=function(options)
    if options.Url:find('raw.githubusercontent.com',1,true) then return {StatusCode=503,Body=SOURCES['main.lua']} end
    return {StatusCode=200,Body=originalGet(game,options.Url)}
end
assert(download('main.lua')==SOURCES['main.lua'],'status failure uses CDN')
for _,bad in ipairs({'','   ','<html>unavailable</html>'}) do
    request=function() return {StatusCode=200,Body=bad} end
    local accepted=pcall(download,'main.lua')
    assert(not accepted,'bad payload accepted: '..bad)
end
request=function() return {Success=false,StatusCode=403,Body=SOURCES['main.lua']} end
assert(not pcall(download,'main.lua'),'HTTP errors must reject valid-looking code')
request=function() return {StatusCode=200,Body='not a PNG'} end
assert(not pcall(download,'assets/hue.png'),'validate PNG before caching')
request=function(options) return {StatusCode=200,Body=originalGet(game,options.Url)} end
MOCK.files['Legit/assets/gradientp90.oh']='old broken image'
local app=assert(loadstring(SOURCES['loader.lua']))()
assert(app.Alive,'standalone loader with nil HttpGet')
assert(MOCK.files['Legit/assets/gradientp90.oh']:sub(1,8)=='\137PNG\r\n\26\n','repair corrupt image cache')
app:Unload()
request=nil
game.HttpGet=function(self,url)
    if url:find('raw.githubusercontent.com',1,true) then return nil end
    return originalGet(self,url)
end
app=assert(loadstring(SOURCES['loader.lua']))()
assert(app.Alive,'standalone CDN fallback without request API')
app:Unload()
assert(nilCompiles==0,'nil was passed to loadstring')
for _,object in ipairs(DRAWINGS) do assert(object.Removed,'download failure leaked Drawing') end
print('PASS nil/empty/HTML responses, status codes, request aliases, CDN fallback, PNG repair and legacy standalone loader; zero nil compiler calls')
