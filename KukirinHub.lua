local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenS     = game:GetService("TweenService")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")
local RS = game:GetService("ReplicatedStorage")

local wheelieOn  = false
local in360      = false
local pumpkinOn  = false
local deliveryOn = false
local kmFarmOn   = false
local gyro,bp,bav,bvFreeze = nil,nil,nil,nil
local delivState = "goPickup"
local kmPos      = nil
local spinLoop   = nil
local s360       = "idle"

local ANGLE       = math.rad(22)
local LIFT        = 60
local SPIN_SPEED  = 9
local KM_INTERVAL = 5
local SPIN_TIME   = (12 * 2 * math.pi) / SPIN_SPEED
local DROP_WAIT   = 5

local PUMPKIN_NAME       = "Pumpkin"
local DELIVERY_NPC_NAME  = "DeliveryNPC"
local DELIVERY_DEST_NAME = "DeliveryDest"
local PICKUP_RE_NAME     = "GetDelivery"
local DROPOFF_RE_NAME    = "CompleteDelivery"

-- GUI
local sg = Instance.new("ScreenGui")
sg.Name="KukirinHub"; sg.ResetOnSpawn=false; sg.Parent=pg

local frame = Instance.new("Frame")
frame.Size=UDim2.new(0,215,0,395)
frame.Position=UDim2.new(0.5,-107,0.5,-197)
frame.BackgroundColor3=Color3.fromRGB(13,13,21)
frame.BorderSizePixel=0; frame.Parent=sg
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,16)
local fStroke=Instance.new("UIStroke",frame)
fStroke.Color=Color3.fromRGB(70,70,110); fStroke.Thickness=1.2; fStroke.Transparency=0.3

-- title bar
local titleBar=Instance.new("Frame",frame)
titleBar.Size=UDim2.new(1,0,0,40); titleBar.BackgroundColor3=Color3.fromRGB(22,22,38)
titleBar.BorderSizePixel=0
Instance.new("UICorner",titleBar).CornerRadius=UDim.new(0,16)
local tFill=Instance.new("Frame",titleBar)
tFill.Size=UDim2.new(1,0,0,16); tFill.Position=UDim2.new(0,0,1,-16)
tFill.BackgroundColor3=Color3.fromRGB(22,22,38); tFill.BorderSizePixel=0
local titleLbl=Instance.new("TextLabel",titleBar)
titleLbl.Size=UDim2.new(1,0,1,0); titleLbl.BackgroundTransparency=1
titleLbl.TextColor3=Color3.fromRGB(210,210,255); titleLbl.Font=Enum.Font.GothamBold
titleLbl.TextSize=14; titleLbl.Text="🛴  KUKIRIN HUB"

local function sep(y)
    local s=Instance.new("Frame",frame)
    s.Size=UDim2.new(1,-16,0,1); s.Position=UDim2.new(0,8,0,y)
    s.BackgroundColor3=Color3.fromRGB(45,45,75); s.BorderSizePixel=0
end

local function secLbl(y,txt)
    local l=Instance.new("TextLabel",frame)
    l.Size=UDim2.new(1,-16,0,14); l.Position=UDim2.new(0,8,0,y)
    l.BackgroundTransparency=1; l.TextColor3=Color3.fromRGB(90,90,140)
    l.Font=Enum.Font.GothamBold; l.TextSize=10; l.Text=txt
    l.TextXAlignment=Enum.TextXAlignment.Left
end

local function mkBtn(pos,sz,col,txt)
    local b=Instance.new("TextButton",frame)
    b.Position=pos; b.Size=sz; b.BackgroundColor3=col
    b.TextColor3=Color3.fromRGB(255,255,255); b.Font=Enum.Font.GothamBold
    b.TextSize=15; b.Text=txt; b.BorderSizePixel=0
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
    return b
end

local function statusLbl(y)
    local l=Instance.new("TextLabel",frame)
    l.Size=UDim2.new(1,-16,0,16); l.Position=UDim2.new(0,8,0,y)
    l.BackgroundTransparency=1; l.TextColor3=Color3.fromRGB(150,150,220)
    l.Font=Enum.Font.GothamBold; l.TextSize=11; l.Text=""
    l.TextXAlignment=Enum.TextXAlignment.Center
    return l
end

local FW = UDim2.new(1,-16,0,42)

sep(44)
secLbl(50,"TRICKS")
local wBtn = mkBtn(UDim2.new(0,8,0,68),  FW, Color3.fromRGB(45,45,180),  "WHEELIE: OFF")
local tBtn = mkBtn(UDim2.new(0,8,0,116), FW, Color3.fromRGB(100,30,180), "360: OFF")
local t360Label = statusLbl(162)

sep(182)
secLbl(189,"FARM")
local pBtn = mkBtn(UDim2.new(0,8,0,206), FW, Color3.fromRGB(160,85,15),  "PUMPKIN: OFF")
local dBtn = mkBtn(UDim2.new(0,8,0,254), FW, Color3.fromRGB(15,110,110), "DELIVERY: OFF")

sep(300)
secLbl(308,"KM FARM")
local setPosBtn = mkBtn(UDim2.new(0,8,0,326),   UDim2.new(0.5,-10,0,42), Color3.fromRGB(55,55,70),   "SET POS")
local kmBtn     = mkBtn(UDim2.new(0.5,2,0,326), UDim2.new(0.5,-10,0,42), Color3.fromRGB(140,15,85),  "KM: OFF")
local cdLabel   = statusLbl(372)

local function tw(obj,props)
    TweenS:Create(obj,TweenInfo.new(0.15),props):Play()
end

-- helpers
local function getRoot()
    local c=lp.Character; if not c then return end
    local h=c:FindFirstChildOfClass("Humanoid")
    local seat=h and h.SeatPart; if not seat then return end
    local model=seat:FindFirstAncestorOfClass("Model"); if not model then return seat end
    if model.PrimaryPart then return model.PrimaryPart end
    local best,bestM=seat,0
    for _,v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") and not v.Anchored then
            local m=v:GetMass(); if m>bestM then best=v;bestM=m end
        end
    end
    return best
end

local function getHRP()
    local c=lp.Character; if not c then return end
    return c:FindFirstChild("HumanoidRootPart")
end

local function tpTo(pos)
    local h=getHRP(); if not h then return end
    h.CFrame=CFrame.new(pos+Vector3.new(0,3,0))
end

local function findInWorkspace(name)
    local h=getHRP(); local best,bestD=nil,math.huge
    for _,v in ipairs(workspace:GetDescendants()) do
        if v.Name==name and v:IsA("BasePart") then
            if h then
                local d=(v.Position-h.Position).Magnitude
                if d<bestD then best=v;bestD=d end
            else return v end
        end
    end
    return best
end

local function fireRE(name)
    local re=RS:FindFirstChild(name,true)
    if re and re:IsA("RemoteEvent") then re:FireServer() end
end

-- 360 system
local function cleanUp360()
    if gyro then gyro:Destroy();gyro=nil end
    if bp   then bp:Destroy();bp=nil end
    if bav  then bav:Destroy();bav=nil end
    if bvFreeze then bvFreeze:Destroy();bvFreeze=nil end
    s360="idle"; t360Label.Text=""
end

local function freeze360(root)
    if bvFreeze then bvFreeze:Destroy() end
    bvFreeze=Instance.new("BodyVelocity")
    bvFreeze.Velocity=Vector3.zero
    bvFreeze.MaxForce=Vector3.new(1e6,1e6,1e6)
    bvFreeze.P=1e6; bvFreeze.Parent=root
end

local function unfreeze360()
    if bvFreeze then bvFreeze:Destroy();bvFreeze=nil end
end

local function liftUp(root)
    if gyro then gyro:Destroy() end
    gyro=Instance.new("BodyGyro")
    gyro.MaxTorque=Vector3.new(8e5,0,8e5); gyro.P=3e5; gyro.D=800
    gyro.CFrame=CFrame.new(); gyro.Parent=root

    if bp then bp:Destroy() end
    bp=Instance.new("BodyPosition")
    bp.Position=root.Position+Vector3.new(0,LIFT,0)
    bp.MaxForce=Vector3.new(0,1e6,0); bp.P=1e5; bp.D=500; bp.Parent=root

    if bav then bav:Destroy() end
    bav=Instance.new("BodyAngularVelocity")
    bav.MaxTorque=Vector3.new(0,1e6,0); bav.P=1e5
    bav.AngularVelocity=Vector3.zero; bav.Parent=root
end

local function start360Loop()
    spinLoop=task.spawn(function()
        while in360 do
            local root=getRoot()
            if not root then task.wait(0.5); continue end

            s360="lifting"; t360Label.Text="↑ lifting..."

            -- kill horizontal vel — prevents fling when moving
            local killV=Instance.new("BodyVelocity")
            killV.Velocity=Vector3.zero
            killV.MaxForce=Vector3.new(4e4,0,4e4); killV.P=8e3; killV.Parent=root
            task.wait(0.3)
            if killV.Parent then killV:Destroy() end

            if not in360 then break end
            liftUp(root)
            task.wait(0.8)
            if not in360 then break end

            s360="spinning"; t360Label.Text="↻ spinning..."
            if bav and bav.Parent then bav.AngularVelocity=Vector3.new(0,SPIN_SPEED,0) end
            task.wait(SPIN_TIME)
            if not in360 then break end

            if bav and bav.Parent then bav.AngularVelocity=Vector3.zero end
            task.wait(0.15)

            s360="dropping"; t360Label.Text="↓ dropping..."
            if bp  then bp:Destroy();bp=nil end
            if bav then bav:Destroy();bav=nil end
            if gyro then gyro.CFrame=CFrame.new() end -- stay flat for landing

            -- detect ground via velocity.Y going from negative → 0
            local wasFalling=false; local groundHit=false; local timer=0
            while in360 and s360=="dropping" and timer<8 do
                task.wait(0.05); timer=timer+0.05
                if root and root.Parent then
                    local vy=root.Velocity.Y
                    if timer>0.4 then
                        if vy<-3 then wasFalling=true end
                        if wasFalling and math.abs(vy)<1.5 then groundHit=true; break end
                    end
                end
            end

            if not in360 then break end

            s360="grounded"
            if gyro then gyro:Destroy();gyro=nil end
            if groundHit then freeze360(root) end

            for i=DROP_WAIT,1,-1 do
                if not in360 then break end
                t360Label.Text="⏱ up in "..i.."s"
                task.wait(1)
            end

            if not in360 then break end
            unfreeze360()
        end
        cleanUp360()
    end)
end

-- buttons
wBtn.MouseButton1Click:Connect(function()
    wheelieOn=not wheelieOn
    wBtn.Text=wheelieOn and "WHEELIE: ON" or "WHEELIE: OFF"
    tw(wBtn,{BackgroundColor3=wheelieOn and Color3.fromRGB(25,185,75) or Color3.fromRGB(45,45,180)})
    if not wheelieOn and not in360 and gyro then gyro:Destroy();gyro=nil end
end)

tBtn.MouseButton1Click:Connect(function()
    in360=not in360
    tBtn.Text=in360 and "360: ON" or "360: OFF"
    tw(tBtn,{BackgroundColor3=in360 and Color3.fromRGB(180,50,220) or Color3.fromRGB(100,30,180)})
    if in360 then
        local root=getRoot()
        if not root then
            in360=false; tBtn.Text="360: OFF"
            tw(tBtn,{BackgroundColor3=Color3.fromRGB(100,30,180)}); return
        end
        start360Loop()
    else
        if spinLoop then task.cancel(spinLoop);spinLoop=nil end
        cleanUp360()
    end
end)

pBtn.MouseButton1Click:Connect(function()
    pumpkinOn=not pumpkinOn
    pBtn.Text=pumpkinOn and "PUMPKIN: ON" or "PUMPKIN: OFF"
    tw(pBtn,{BackgroundColor3=pumpkinOn and Color3.fromRGB(220,130,0) or Color3.fromRGB(160,85,15)})
end)

dBtn.MouseButton1Click:Connect(function()
    deliveryOn=not deliveryOn
    dBtn.Text=deliveryOn and "DELIVERY: ON" or "DELIVERY: OFF"
    tw(dBtn,{BackgroundColor3=deliveryOn and Color3.fromRGB(25,185,185) or Color3.fromRGB(15,110,110)})
    delivState="goPickup"
end)

setPosBtn.MouseButton1Click:Connect(function()
    local root=getRoot()
    if root then
        kmPos=root.Position
        tw(setPosBtn,{BackgroundColor3=Color3.fromRGB(25,185,75)})
        task.delay(0.5,function() tw(setPosBtn,{BackgroundColor3=Color3.fromRGB(55,55,70)}) end)
    end
end)

kmBtn.MouseButton1Click:Connect(function()
    if not kmPos then
        tw(kmBtn,{BackgroundColor3=Color3.fromRGB(200,40,40)})
        task.delay(0.4,function() tw(kmBtn,{BackgroundColor3=Color3.fromRGB(140,15,85)}) end)
        cdLabel.Text="set pos first!"; return
    end
    kmFarmOn=not kmFarmOn
    kmBtn.Text=kmFarmOn and "KM: ON" or "KM: OFF"
    tw(kmBtn,{BackgroundColor3=kmFarmOn and Color3.fromRGB(210,30,140) or Color3.fromRGB(140,15,85)})
    if not kmFarmOn then cdLabel.Text="" end
end)

-- drag
local drag,dragStart,startPos=false,nil,nil
frame.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch or
       i.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true;dragStart=i.Position;startPos=frame.Position end
end)
frame.InputChanged:Connect(function(i)
    if drag and (i.UserInputType==Enum.UserInputType.Touch or
                 i.UserInputType==Enum.UserInputType.MouseMove) then
        local d=i.Position-dragStart
        frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                                  startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
frame.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)

-- pumpkin loop
task.spawn(function()
    while true do
        task.wait(0.15)
        if pumpkinOn then
            local p=findInWorkspace(PUMPKIN_NAME)
            if p then tpTo(p.Position) end
        end
    end
end)

-- delivery loop
task.spawn(function()
    while true do
        task.wait(0.4)
        if deliveryOn then
            if delivState=="goPickup" then
                local npc=findInWorkspace(DELIVERY_NPC_NAME)
                if npc then tpTo(npc.Position);task.wait(0.5);fireRE(PICKUP_RE_NAME);task.wait(0.3);delivState="goDropoff" end
            elseif delivState=="goDropoff" then
                local dest=findInWorkspace(DELIVERY_DEST_NAME)
                if dest then tpTo(dest.Position);task.wait(0.5);fireRE(DROPOFF_RE_NAME);task.wait(0.3);delivState="goPickup" end
            end
        end
    end
end)

-- km farm loop
task.spawn(function()
    while true do
        if kmFarmOn and kmPos then
            for i=KM_INTERVAL,1,-1 do
                if not kmFarmOn then break end
                cdLabel.Text="tp in "..i.."s"; task.wait(1)
            end
            if kmFarmOn and kmPos then
                local root=getRoot()
                if root then root.CFrame=CFrame.new(kmPos+Vector3.new(0,3,0)) end
                local hrp=getHRP()
                if hrp then hrp.CFrame=CFrame.new(kmPos+Vector3.new(0,3,0)) end
            end
        else task.wait(0.5) end
    end
end)

-- heartbeat
RunService.Heartbeat:Connect(function()
    if wheelieOn and not in360 then
        local root=getRoot()
        if not root then
            if gyro then gyro:Destroy();gyro=nil end
        else
            if not gyro or not gyro.Parent or gyro.Parent~=root then
                if gyro then gyro:Destroy() end
                gyro=Instance.new("BodyGyro")
                gyro.MaxTorque=Vector3.new(3e4,0,3e4)
                gyro.P=2.5e4;gyro.D=600;gyro.Parent=root
            end
            local cf=root.CFrame
            local look=Vector3.new(cf.LookVector.X,0,cf.LookVector.Z)
            if look.Magnitude<1e-3 then look=Vector3.new(0,0,-1) else look=look.Unit end
            gyro.CFrame=CFrame.lookAt(Vector3.zero,look,Vector3.new(0,1,0))*CFrame.Angles(ANGLE,0,0)
        end
    end
    if in360 and (s360=="spinning" or s360=="lifting") then
        if gyro and gyro.Parent then gyro.CFrame=CFrame.new() end
    end
end)
