local vec=MOCK.vec
workspace.DescendantAdded=Instance.new('BindableEvent').Activated
local character=Instance.new('Model'); character.Parent=workspace
local root=Instance.new('Part'); root.Parent=character; root.Position=vec(0,0,0); root.Anchored=false
character.Children.HumanoidRootPart=root
local hum=Instance.new('Humanoid'); hum.Parent=character; hum.Health=100; hum.MoveDirection=vec(0,0,0); character.Children.Humanoid=hum
local tool=Instance.new('Tool'); tool.Name='RPG'; tool.Parent=character; character.Children.Tool=tool
MOCK.players.LocalPlayer.Character=character
local camera=workspace.CurrentCamera; camera.CameraSubject=hum
local app=assert(loadstring(SOURCES['main.lua']))()
local control,s=app.ProjectileControl,app.Config.Projectiles
s.Rockets=true; s.C4=true; control:Step(0)
local function projectile(name,creator)
    local object=Instance.new('Part'); object.Name=name; object.Parent=workspace; object.Position=vec(2,0,0); object.CFrame=CFrame.lookAt(vec(2,0,0),vec(2,0,1)); object.Massless=false
    if creator then local owner=Instance.new('ObjectValue'); owner.Value=creator; owner.Parent=object; object.Children.Creator=owner end
    return object
end
local rocket=projectile('RPG_Rocket')
assert(not control:TryControl(rocket),'unattributed projectile requires own recent launch')
tool.Activated:Fire()
assert(not control:TryControl(projectile('RPG_Rocket',{})),'explicit foreign ownership always rejected')
local force=Instance.new('BodyForce'); force.Parent=rocket; rocket.Children.BodyForce=force
local rot=Instance.new('Part'); rot.Parent=rocket; rocket.Children.RotPart=rot
local angular=Instance.new('BodyAngularVelocity'); angular.Parent=rot; rot.Children.BodyAngularVelocity=angular
workspace.DescendantAdded:Fire(rocket); control:Step(1/60)
assert(control.active and control.active.Object==rocket,'streamed projectile acquired after own launcher activation')
assert(root.Anchored and camera.CameraSubject==rocket and app.Engine.ProjectileControl,'camera and character acquired')
assert(force.Parent==nil,'old mover suspended')
assert(angular.Parent==nil,'nested rocket spin suspended')
control:Step(0.1); assert(control.active.Mover.Position.Z>rocket.Position.Z,'rocket steering follows camera')
local mover=control.active.Mover
MOCK.services.UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.X})
assert(not root.Anchored and camera.CameraSubject==hum and mover.Destroyed and force.Parent==rocket,'X restores camera/root/movers')
assert(angular.Parent==rot,'nested mover returns to its original parent')
local c4=projectile('TransIgnore',MOCK.players.LocalPlayer)
assert(control:TryControl(c4),'own C4')
control:Step(0.1); assert(control.active.Mover.Velocity.Magnitude==s.Speed,'C4 velocity')
workspace.DescendantAdded:Fire({Name='C4Explosion'})
assert(not control.active and not root.Anchored and camera.CameraSubject==hum,'explosion cleanup')
assert(control:TryControl(projectile('AT4_Rocket',MOCK.players.LocalPlayer)),'other supported rocket')
s.Rockets=false; control:Step(0); assert(not control.active and not root.Anchored,'disable releases'); s.Rockets=true
local own=projectile('RPG_Rocket',MOCK.players.LocalPlayer); control:TryControl(own); own.Parent=nil; control:Step(0)
assert(not control.active and not root.Anchored,'projectile deletion releases')
control:TryControl(projectile('RPG_Rocket',MOCK.players.LocalPlayer)); hum.Health=0; control:Step(0)
assert(not control.active and not root.Anchored,'death releases'); hum.Health=100
control:TryControl(projectile('RPG_Rocket',MOCK.players.LocalPlayer)); MOCK.players.LocalPlayer.Character=nil; control:Step(0)
assert(not control.active and not root.Anchored,'respawn releases'); MOCK.players.LocalPlayer.Character=character
control:TryControl(projectile('RPG_Rocket',MOCK.players.LocalPlayer)); app.Tools:SetSpectating(true)
assert(not control.active,'spectating releases projectile without camera conflict')
root.Anchored=true; control:TryControl(projectile('RPG_Rocket',MOCK.players.LocalPlayer)); control:Release()
assert(root.Anchored,'preexisting anchor preserved'); root.Anchored=false
control:TryControl(projectile('RPG_Rocket',MOCK.players.LocalPlayer)); local external={Parent=workspace}; camera.CameraSubject=external; control:Release()
assert(camera.CameraSubject==external,'newer external camera owner preserved'); camera.CameraSubject=hum
control:TryControl(projectile('RPG_Rocket',MOCK.players.LocalPlayer)); app:Unload()
assert(not control.active and not root.Anchored and camera.CameraSubject==hum and not control.heartbeat.Connected and not control.input.Connected,'unload restores and disconnects')
print('PASS C4/rockets: own launch scope, steering, camera/root restoration, disable/explosion/death/respawn, spectate and unload')
