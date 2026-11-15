-- Matrix-backed rotations verify yaw/pitch and translation independently.
local vec=MOCK.vec
local frame={}
local function cf(pos,m)
    return setmetatable({Position=pos,M=m,LookVector=vec(-m[3],-m[6],-m[9])},frame)
end
frame.__index=function(self,key)
    if key=='Rotation' then return cf(vec(0,0,0),self.M) end
    if key=='Inverse' then return function(a)
        local m=a.M
        local inv=cf(vec(0,0,0),{m[1],m[4],m[7],m[2],m[5],m[8],m[3],m[6],m[9]})
        local p=a.Position
        inv.Position=vec(-(m[1]*p.X+m[4]*p.Y+m[7]*p.Z),-(m[2]*p.X+m[5]*p.Y+m[8]*p.Z),-(m[3]*p.X+m[6]*p.Y+m[9]*p.Z))
        return inv
    end end
end
frame.__mul=function(a,b)
    local m={}
    for row=0,2 do for col=1,3 do
        m[row*3+col]=0
        for k=1,3 do m[row*3+col]+=a.M[row*3+k]*b.M[(k-1)*3+col] end
    end end
    local v=b.Position
    return cf(a.Position+vec(a.M[1]*v.X+a.M[2]*v.Y+a.M[3]*v.Z,
        a.M[4]*v.X+a.M[5]*v.Y+a.M[6]*v.Z,a.M[7]*v.X+a.M[8]*v.Y+a.M[9]*v.Z),m)
end
CFrame.new=function(pos) return cf(pos or vec(0,0,0),{1,0,0,0,1,0,0,0,1}) end
CFrame.Angles=function(x,y,z)
    local c,s=math.cos,math.sin
    return cf(vec(0,0,0),{1,0,0,0,c(x),-s(x),0,s(x),c(x)})
        *cf(vec(0,0,0),{c(y),0,s(y),0,1,0,-s(y),0,c(y)})
        *cf(vec(0,0,0),{c(z),-s(z),0,s(z),c(z),0,0,0,1})
end
local function fixture(r15)
    local char=Instance.new('Model')
    local root=Instance.new('Part'); root.Position=vec(10,5,20); root.CFrame=CFrame.new(root.Position); root.Parent=char
    char.Children.HumanoidRootPart=root
    local hum=Instance.new('Humanoid'); hum.Health=100; hum.AutoRotate=true; hum.Parent=char; char.Children.Humanoid=hum
    local torso=Instance.new('Part'); char.Children[r15 and 'UpperTorso' or 'Torso']=torso
    local neck=Instance.new('Motor6D'); neck.Parent=torso; torso.Children.Neck=neck
    neck.C0=CFrame.new(vec(0,1,0)); neck.C1=CFrame.new(); neck.Transform=CFrame.new(); neck.Part0=root
    return char,hum,root,neck
end
local app=assert(loadstring(SOURCES['main.lua']))()
local tools,c=app.Tools,app.Config.Character
local char,hum,root,neck=fixture(false); MOCK.players.LocalPlayer.Character=char
local original=neck.C0; local camera=workspace.CurrentCamera.CFrame
c.Spinbot=true; c.SpinSpeed=360; c.SpinPitch=70
tools:Step(0.1)
assert(not hum.AutoRotate and math.abs(root.CFrame.LookVector.X+math.sin(math.rad(36)))<1e-8,'spin uses degrees per second')
assert((root.CFrame.Position-root.Position).Magnitude<1e-8 and workspace.CurrentCamera.CFrame==camera,'position and camera preserved')
assert(neck.C0.LookVector.Y>0.9 and neck.C0.Position.Y==1,'look up preserves neck position')
tools:Step(0.1); assert(math.abs(neck.C0.LookVector.Y-math.sin(math.rad(70)))<1e-8,'pitch does not accumulate')
local run=MOCK.services.RunService
local render=assert(run.bindings[tools.spinRenderName])
assert(run.priorities[tools.spinRenderName]>run.priorities[app.Engine.renderName],'spin renders after camera/aim')
local weaponPose=original*CFrame.Angles(-0.5,0,0)
local weaponC1=CFrame.Angles(0,0,0.2)
local animation=CFrame.Angles(-0.3,0,0)
local phase=tools.spinYaw
-- Emulate gun aim/animation overwriting all three neck properties after physics.
root.CFrame=CFrame.new(root.Position); hum.AutoRotate=true
neck.C0=weaponPose; neck.C1=weaponC1; neck.Transform=animation
render(0.1)
assert(math.abs(root.CFrame.LookVector.X+math.sin(phase))<1e-8 and tools.spinYaw==phase,'late spin defeats weapon yaw without double advancing time')
assert(not hum.AutoRotate and math.abs(neck.C0.LookVector.Y-math.sin(math.rad(70)))<1e-8,'gun aim cannot alter forced head pitch')
assert(neck.C1.LookVector.Y==0 and neck.Transform.LookVector.Y==0,'neck aim offsets and animation overridden')
root.CFrame=CFrame.new(root.Position); tools:Step(0.1)
assert(math.abs(tools.spinYaw-phase-math.rad(36))<1e-8,'spin phase continues independently of repeated cursor resets')
for _=1,30 do
    tools:Step(1/60)
    local expected=tools.spinYaw
    root.CFrame=CFrame.new(root.Position); hum.AutoRotate=true
    neck.C0=weaponPose; neck.C1=weaponC1; neck.Transform=animation
    render(1/60)
    assert(math.abs(root.CFrame.LookVector.X+math.sin(expected))<1e-8,'weapon cannot stop sustained spin')
    assert(math.abs(neck.C0.LookVector.Y-math.sin(math.rad(70)))<1e-8,'weapon cannot lower sustained head pose')
end
assert(workspace.CurrentCamera.CFrame==camera,'forced pose leaves camera unchanged')
hum.Sit=true; tools:Step(0.1); assert(hum.AutoRotate and neck.C0==weaponPose and neck.C1==weaponC1 and neck.Transform==animation,'pause restores latest game pose and autorotate')
hum.Sit=false; tools:Step(0.1)
local nextChar,nextHum,nextRoot,nextNeck=fixture(true)
MOCK.players.LocalPlayer.Character=nextChar; tools:Step(0.1)
assert(hum.AutoRotate and neck.C0==weaponPose and not nextHum.AutoRotate and nextNeck.C0.LookVector.Y>0.9,'respawn restores old rig and supports R15')
app.Library.options.Character_Spinbot:SetState(false)
assert(nextHum.AutoRotate and nextNeck.C0.LookVector.Y==0,'toggle restores neck')
app.Library.options.Character_Spinbot:SetState(true)
app:Unload(); assert(nextHum.AutoRotate and nextNeck.C0.LookVector.Y==0,'unload restores pose')
assert(not run.bindings[tools.spinRenderName],'unload removes late spin binding')
print('PASS spinbot: yaw rate, neck pitch, fixed position, camera, pause, R6/R15, respawn and restoration')
