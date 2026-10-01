--[[ SysHub - Blair v6.9.37 (Spirit Box: check all players' spirit box) ]]
print("[SysHub] Starting...")
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
print("[SysHub] WindUI loaded")
local Window = WindUI:CreateWindow({
    Title = "SysHub - Blair"; Icon = "rbxassetid://140026247905567";
    Author = "Premium"; Folder = "SysHub";
    Size = UDim2.fromOffset(640, 540); MinSize = Vector2.new(550, 420);
    Resizable = true; Theme = "Sky";
})
print("[SysHub] Window created")
pcall(function()
    Window:EditOpenButton({
        Title = "SysHub - Blair"; Icon = "ghost";
        CornerRadius = UDim.new(0, 30); StrokeThickness = 1.5;
        Color = ColorSequence.new(Color3.fromHex("87CEFA"), Color3.fromHex("191970"));
        OnlyMobile = false; Enabled = true; Draggable = true;
    })
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local AchievementEvents = ReplicatedStorage:FindFirstChild("AchievementServiceEvents")
local OnAchievementAwarded = AchievementEvents and AchievementEvents:FindFirstChild("OnAchievementAwarded")
local SelectGhostRemote = Remotes and (Remotes:FindFirstChild("SelectGhost") or Remotes:FindFirstChild("SelectGhost1"))
local UVPartRemote = Remotes and Remotes:FindFirstChild("UVPartInteraction")
local DiscoveredOrbsRemote = Remotes and Remotes:FindFirstChild("PlayerDiscoveredGhostOrbs")
local DiscoveredSLSRemote = Remotes and Remotes:FindFirstChild("PlayerDiscoveredSLSAnomaly")
local PlayerSawSLSLeaveRoomRemote = Remotes and Remotes:FindFirstChild("PlayerSawSLSLeaveRoom")
local FreezingObjectiveRemote = Remotes and Remotes:FindFirstChild("FreezingTemperatureObjective")
local GhostInLOSRemote = Remotes and Remotes:FindFirstChild("GhostinLOS")
local TypewriteRemote = Remotes and Remotes:FindFirstChild("Typewrite")
local PrintOnClientRemote = Remotes and Remotes:FindFirstChild("PrintOnClient")
local PrintStringOnClientRemote = Remotes and Remotes:FindFirstChild("PrintStringOnClient")

local ghostEvidencesMap = {
    Krasue = {"EMF Level 5", "Freezing Temperatures", "Ultraviolet"};
    Strigoi = {"Ultraviolet", "Ghost Orb", "EMF Level 5"};
    Revenant = {"EMF Level 5", "Ultraviolet", "Ghost Writing"};
    Phantom = {"Ghost Orb", "Ultraviolet", "SLS Anomaly"};
    Faejkur = {"EMF Level 5", "Freezing Temperatures", "Ghost Writing"};
    Shade = {"EMF Level 5", "SLS Anomaly", "Ghost Writing"};
    ZoZo = {"EMF Level 5", "Ultraviolet", "Spirit Box"};
    Yama = {"Ghost Writing", "Spirit Box", "SLS Anomaly"};
    Nook = {"EMF Level 5", "Freezing Temperatures", "Ghost Orb"};
    Mare = {"Freezing Temperatures", "SLS Anomaly", "Spirit Box"};
    Poltergeist = {"Ultraviolet", "Ghost Orb", "Spirit Box"};
    Harrow = {"SLS Anomaly", "Ghost Orb", "Ghost Writing"};
    Oni = {"SLS Anomaly", "Ultraviolet", "Ghost Writing"};
    Yurei = {"Ultraviolet", "Freezing Temperatures", "Spirit Box"};
    Jiangshi = {"Freezing Temperatures", "Ultraviolet", "SLS Anomaly"};
    Demon = {"Freezing Temperatures", "Ghost Writing", "Spirit Box"};
    Lament = {"Ghost Orb", "EMF Level 5", "Spirit Box"};
    Banshee = {"EMF Level 5", "SLS Anomaly", "Freezing Temperatures"};
    Spirit = {"Ultraviolet", "Ghost Writing", "Spirit Box"};
    Wraith = {"Freezing Temperatures", "Ghost Orb", "SLS Anomaly"};
    Vuult = {"EMF Level 5", "Ghost Orb", "SLS Anomaly"};
}

local detectedEvidences = {}
local ghostRoomTemp = nil
local ghostRoomName = nil
local autoEvidenceDetectActive = false
local autoLockGhostActive = false
local autoDeduce3rdEvidence = true
local instantInteractEnabled = false
local infiniteStaminaEnabled = false
local infiniteNoclipEnabled = false
local customWalkSpeedEnabled = false
local huntNotifyEnabled = true
local targetWalkSpeed = 20
local DEFAULT_WALKSPEED = 20
local originalWalkSpeed = nil
local capturedSprintSpeed = nil
local autoStatusParagraph = nil
local walkSpeedSlider = nil
local statusUpdateFailures = 0
local STATUS_MAX_FAILURES = 3
local hookedTools = setmetatable({}, {__mode = "k"})
local hookedRemotes = setmetatable({}, {__mode = "k"})
local hookedValueObjects = setmetatable({}, {__mode = "k"})
local debugCounts = setmetatable({}, {__mode = "k"})
local uvEvidenceFired = false
local ghostOrbEvidenceFired = false
local lastHuntNotify = 0

local function safeNotify(opts)
    pcall(function()
        WindUI:Notify(opts)
    end)
end

local function isFreezingValue(val)
    if type(val) ~= "number" then
        return false
    end
    if val <= 0 then
        return true
    end
    return math.floor(val * 100 + 0.5) / 100 <= 0.09
end

local function matchGhostsFromEvidences(list)
    if not list or #list == 0 then
        return {}
    end
    local out = {}
    for ghost, evs in pairs(ghostEvidencesMap) do
        local ok = true
        for _, sel in ipairs(list) do
            local found = false
            for _, ge in ipairs(evs) do
                if string.lower(ge) == string.lower(sel) then
                    found = true
                    break
                end
            end
            if not found then
                ok = false
                break
            end
        end
        if ok then
            table.insert(out, ghost)
        end
    end
    table.sort(out)
    return out
end

local function selectGhostInJournal(name)
    if not name or name == "" then
        return
    end
    pcall(function()
        if SelectGhostRemote then
            SelectGhostRemote:FireServer(name)
        end
    end)
end

local function updateAutoStatusText()
    local count = #detectedEvidences
    local evStr = (count > 0) and ("- " .. table.concat(detectedEvidences, "\n- ")) or "Belum ada bukti"
    local cand = matchGhostsFromEvidences(detectedEvidences)
    local ghostStr = "Menunggu bukti..."
    if count > 0 then
        if #cand == 1 then
            ghostStr = "PASTI: " .. cand[1]
        elseif #cand == 0 then
            ghostStr = "Tidak ada cocok"
        else
            ghostStr = "Sisa " .. #cand .. ": " .. table.concat(cand, ", ")
        end
    end
    local tempStr = ""
    if ghostRoomTemp then
        tempStr = "\nSuhu Ghost Room: " .. string.format("%.2f", ghostRoomTemp) .. " C"
        if ghostRoomName then
            tempStr = tempStr .. " (" .. ghostRoomName .. ")"
        end
    else
        tempStr = "\nSuhu Ghost Room: menunggu data..."
    end
    local activeStr = autoEvidenceDetectActive and "" or "\n[Auto Detect: OFF]"
    return "Bukti (" .. count .. "/3)" .. tempStr .. activeStr .. "\n\n" .. evStr .. "\n\nAnalisis:\n" .. ghostStr
end

local STATUS_REFRESH_INTERVAL = 0.5
local lastStatusRefresh = 0

local function refreshAutoStatusUI(force)
    if not autoStatusParagraph then
        return
    end
    if statusUpdateFailures >= STATUS_MAX_FAILURES then
        return
    end
    local now = tick()
    if not force and (now - lastStatusRefresh) < STATUS_REFRESH_INTERVAL then
        return
    end
    lastStatusRefresh = now
    local t = updateAutoStatusText()
    local ok = pcall(function()
        if autoStatusParagraph.Set then
            autoStatusParagraph:Set(t)
        elseif autoStatusParagraph.SetContent then
            autoStatusParagraph:SetContent(t)
        elseif autoStatusParagraph.SetDesc then
            autoStatusParagraph:SetDesc(t)
        end
    end)
    if not ok then
        statusUpdateFailures = statusUpdateFailures + 1
        if statusUpdateFailures >= STATUS_MAX_FAILURES then
            autoStatusParagraph = nil
        end
    end
end

local function addDetectedEvidence(name)
    if not autoEvidenceDetectActive or not name or name == "" then
        return
    end
    for _, e in ipairs(detectedEvidences) do
        if string.lower(e) == string.lower(name) then
            return
        end
    end
    table.insert(detectedEvidences, name)
    safeNotify({Title = "BUKTI!", Content = "[" .. #detectedEvidences .. "/3] " .. name, Duration = 5})
    print("[SysHub] Evidence: " .. name)
    local cand = matchGhostsFromEvidences(detectedEvidences)
    if #cand == 1 and autoLockGhostActive then
        local canLock = (#detectedEvidences >= 3) or (autoDeduce3rdEvidence and #detectedEvidences >= 2)
        if canLock then
            selectGhostInJournal(cand[1])
            safeNotify({Title = "TERKUNCI!", Content = cand[1], Duration = 6})
        end
    end
    refreshAutoStatusUI(true)
end

local function updateGhostRoomTemp()
    local map = Workspace:FindFirstChild("Map")
    local zones = map and map:FindFirstChild("Zones")
    if not zones then
        return
    end
    local coldest, coldestTemp = nil, 999
    for _, z in ipairs(zones:GetChildren()) do
        local zn = z.Name:lower()
        local skip = z:FindFirstChild("Exclude")
            or zn:find("hitbox")
            or zn:find("zonelist")
            or zn == "zones"
        if not skip then
            local tv = z:FindFirstChild("_____Temperature")
            if tv and tv:IsA("NumberValue") and typeof(tv.Value) == "number" then
                if tv.Value < coldestTemp then
                    coldestTemp = tv.Value
                    coldest = z
                end
            end
        end
    end
    if coldest then
        ghostRoomTemp = coldestTemp
        ghostRoomName = coldest.Name
        if autoEvidenceDetectActive and isFreezingValue(coldestTemp) then
            addDetectedEvidence("Freezing Temperatures")
        end
    else
        ghostRoomTemp = nil
        ghostRoomName = nil
    end
end

task.spawn(function()
    while true do
        pcall(updateGhostRoomTemp)
        refreshAutoStatusUI()
        task.wait(1)
    end
end)

local function notifyHunt(source)
    if not huntNotifyEnabled then
        return
    end
    local now = tick()
    if now - lastHuntNotify < 5 then
        return
    end
    lastHuntNotify = now
    safeNotify({Title = "⚠️ GHOST HUNTING!", Content = "Ghost mulai berburu! [" .. tostring(source or "?") .. "]", Duration = 4})
    print("[SysHub] HUNT: " .. tostring(source))
end

local watchedHuntingValues = setmetatable({}, {__mode = "k"})

local function isSLSVisualModel(name)
    return name == "SLS_GHOST"
end

local function isIgnoredModel(name)
    return name == "ShadowyFigure"
end

local function isRealGhostModel(model)
    if not model or not model:IsA("Model") then
        return false
    end
    if isIgnoredModel(model.Name) then
        return false
    end
    if model:IsA("Tool") then
        return false
    end
    local p = model.Parent
    while p do
        if p:IsA("Tool") then
            return false
        end
        p = p.Parent
    end
    local fullName = model:GetFullName()
    if fullName:find("Map.Items", 1, true) or fullName:find("Backpack", 1, true) then
        return false
    end
    local hasGhostAttr = model:GetAttribute("Ghost") ~= nil
        or model:GetAttribute("OriginalGhostName") ~= nil
    local hasGhostChild = model:FindFirstChild("OriginalGhostName") ~= nil
    local nameLow = model.Name:lower()
    local isGhostName = nameLow:find("ghost")
    local isSLSName = isSLSVisualModel(model.Name)
    return hasGhostAttr or hasGhostChild or isGhostName or isSLSName
end

local function watchHuntingValue(bv, modelName, isSLSVisual)
    if not bv or not bv:IsA("BoolValue") or watchedHuntingValues[bv] then
        return
    end
    watchedHuntingValues[bv] = true
    bv:GetPropertyChangedSignal("Value"):Connect(function()
        if not bv.Value then
            return
        end
        if isSLSVisual then
            if autoEvidenceDetectActive then
                addDetectedEvidence("SLS Anomaly")
            end
        else
            notifyHunt("Hunting=" .. modelName)
        end
    end)
    if bv.Value then
        if isSLSVisual then
            if autoEvidenceDetectActive then
                addDetectedEvidence("SLS Anomaly")
            end
        else
            notifyHunt("Hunting=" .. modelName)
        end
    end
end

local function inspectHuntModel(model)
    if not model or not model:IsA("Model") then
        return
    end
    if Players:GetPlayerFromCharacter(model) then
        return
    end
    if isIgnoredModel(model.Name) then
        return
    end
    if not isRealGhostModel(model) then
        return
    end
    local isSLSVisual = isSLSVisualModel(model.Name)
    if isSLSVisual and autoEvidenceDetectActive then
        addDetectedEvidence("SLS Anomaly")
    end
    local hv = model:FindFirstChild("Hunting") or model:FindFirstChild("HuntingValue")
    if hv then
        watchHuntingValue(hv, model.Name, isSLSVisual)
    end
end

task.spawn(function()
    for _, v in ipairs(Workspace:GetChildren()) do
        inspectHuntModel(v)
    end
    Workspace.ChildAdded:Connect(function(c)
        task.wait(0.2)
        inspectHuntModel(c)
        if c:IsA("Model") and not isIgnoredModel(c.Name) then
            for _, d in ipairs(c:GetChildren()) do
                if d:IsA("BoolValue") then
                    watchHuntingValue(d, c.Name, isSLSVisualModel(c.Name))
                end
            end
        end
    end)
end)

if GhostInLOSRemote and GhostInLOSRemote:IsA("RemoteEvent") then
    GhostInLOSRemote.OnClientEvent:Connect(function()
        notifyHunt("GhostinLOS")
    end)
end

local EVIDENCE_PATTERNS = {
    {pat = "emflevel5", ev = "EMF Level 5"};
    {pat = "emflevelfive", ev = "EMF Level 5"};
    {pat = "emf_level_5", ev = "EMF Level 5"};
    {pat = "emf5", ev = "EMF Level 5"};
    {pat = "freezingtemperature", ev = "Freezing Temperatures"};
    {pat = "freezing_temperature", ev = "Freezing Temperatures"};
    {pat = "freezingtempature", ev = "Freezing Temperatures"};
    {pat = "isfreezing", ev = "Freezing Temperatures"};
    {pat = "ghostwriting", ev = "Ghost Writing"};
    {pat = "ghost_writing", ev = "Ghost Writing"};
    {pat = "haswritten", ev = "Ghost Writing"};
    {pat = "spiritbox", ev = "Spirit Box"};
    {pat = "spirit_box", ev = "Spirit Box"};
    {pat = "ultraviolet", ev = "Ultraviolet"};
    {pat = "uvfingerprint", ev = "Ultraviolet"};
    {pat = "ghostorb", ev = "Ghost Orb"};
    {pat = "ghost_orb", ev = "Ghost Orb"};
    {pat = "slsanomaly", ev = "SLS Anomaly"};
    {pat = "sls_anomaly", ev = "SLS Anomaly"};
}

local function detectEvidenceFromString(s)
    if type(s) ~= "string" then
        return nil
    end
    if #s < 3 or #s > 200 then
        return nil
    end
    local low = s:lower()
    for _, p in ipairs(EVIDENCE_PATTERNS) do
        if low:find(p.pat, 1, true) then
            return p.ev
        end
    end
    return nil
end

-- ============================================================
-- Ghost Orb
-- ============================================================
local function fireGhostOrbEvidence(reason)
    if not autoEvidenceDetectActive then
        return
    end
    if ghostOrbEvidenceFired then
        return
    end
    ghostOrbEvidenceFired = true
    print("[SysHub] Ghost Orb [" .. tostring(reason or "?") .. "] — firing Ghost Orb evidence")
    addDetectedEvidence("Ghost Orb")
end

if DiscoveredOrbsRemote and DiscoveredOrbsRemote:IsA("RemoteEvent") then
    DiscoveredOrbsRemote.OnClientEvent:Connect(function(...)
        fireGhostOrbEvidence("PlayerDiscoveredGhostOrbs")
    end)
end

if OnAchievementAwarded and OnAchievementAwarded:IsA("RemoteEvent") then
    OnAchievementAwarded.OnClientEvent:Connect(function(...)
        local args = {...}
        local allText = ""
        for _, a in ipairs(args) do
            if type(a) == "string" then
                allText = allText .. " " .. a:lower()
            elseif type(a) == "table" then
                for k, v in pairs(a) do
                    if type(v) == "string" then
                        allText = allText .. " " .. v:lower()
                    elseif type(k) == "string" then
                        allText = allText .. " " .. k:lower()
                    end
                end
            end
        end
        if allText:find("orb", 1, true) then
            fireGhostOrbEvidence("Achievement orb")
        end
    end)
    print("[SysHub] Hooked AchievementServiceEvents.OnAchievementAwarded")
end

local ORB_KW = {"ghostorb", "ghost_orb", "ghost orb"}
local function matchesOrbName(name)
    local n = (name or ""):lower()
    for _, kw in ipairs(ORB_KW) do
        if n:find(kw, 1, true) then
            return true
        end
    end
    if n == "orb" or n == "orbs" then
        return true
    end
    return false
end

local function checkOrbInContainer(root)
    if not root or ghostOrbEvidenceFired then
        return
    end
    for _, v in ipairs(root:GetDescendants()) do
        if v:IsA("ParticleEmitter") then
            if v.Enabled and (matchesOrbName(v.Name) or (v.Parent and matchesOrbName(v.Parent.Name))) then
                fireGhostOrbEvidence("ParticleEmitter " .. v:GetFullName():sub(1, 80))
                return
            end
        elseif v:IsA("BasePart") then
            if v.Transparency < 1 and matchesOrbName(v.Name) then
                fireGhostOrbEvidence("BasePart " .. v:GetFullName():sub(1, 80))
                return
            end
        end
    end
end

task.spawn(function()
    local map = Workspace:WaitForChild("Map", 30)
    if not map then
        return
    end
    local orbs = map:WaitForChild("Orbs", 30)
    if orbs then
        print("[SysHub] Hooked Map.Orbs for Ghost Orb detection")
        orbs.DescendantAdded:Connect(function(d)
            if not autoEvidenceDetectActive or ghostOrbEvidenceFired then
                return
            end
            task.wait(0.05)
            if d:IsA("ParticleEmitter") and d.Enabled and (matchesOrbName(d.Name) or (d.Parent and matchesOrbName(d.Parent.Name))) then
                fireGhostOrbEvidence("Map.Orbs ParticleEmitter")
            end
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        if autoEvidenceDetectActive and not ghostOrbEvidenceFired then
            local map = Workspace:FindFirstChild("Map")
            if map then
                local orbs = map:FindFirstChild("Orbs")
                if orbs then
                    checkOrbInContainer(orbs)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(10)
        if autoEvidenceDetectActive and not ghostOrbEvidenceFired then
            checkOrbInContainer(Workspace)
        end
    end
end)

if DiscoveredSLSRemote and DiscoveredSLSRemote:IsA("RemoteEvent") then
    DiscoveredSLSRemote.OnClientEvent:Connect(function(...)
        if autoEvidenceDetectActive then
            addDetectedEvidence("SLS Anomaly")
        end
    end)
end

if PlayerSawSLSLeaveRoomRemote and PlayerSawSLSLeaveRoomRemote:IsA("RemoteEvent") then
    PlayerSawSLSLeaveRoomRemote.OnClientEvent:Connect(function(...)
        if autoEvidenceDetectActive then
            addDetectedEvidence("SLS Anomaly")
        end
    end)
end

if FreezingObjectiveRemote and FreezingObjectiveRemote:IsA("RemoteEvent") then
    FreezingObjectiveRemote.OnClientEvent:Connect(function(...)
        if not autoEvidenceDetectActive then
            return
        end
        if ghostRoomTemp and isFreezingValue(ghostRoomTemp) then
            addDetectedEvidence("Freezing Temperatures")
        end
    end)
end

-- ============================================================
-- UV Detection
-- ============================================================
local function fireUVEvidence(reason)
    if not autoEvidenceDetectActive then
        return
    end
    if uvEvidenceFired then
        return
    end
    uvEvidenceFired = true
    print("[SysHub] UV revealed [" .. tostring(reason or "?") .. "] — firing Ultraviolet evidence")
    addDetectedEvidence("Ultraviolet")
end

local UV_STRICT_KW = {"uv_fingerprint", "uv_hand", "uv_foot", "uv_print", "uv_palm", "uv_mark",
                       "uvfingerprint", "uvhandprint", "uvfootprint", "uvpalmprint"}

local function matchesUVName(name)
    local n = (name or ""):lower()
    if n == "uv_part" or n == "uvpart" then
        return false
    end
    for _, kw in ipairs(UV_STRICT_KW) do
        if n:find(kw, 1, true) then
            return true
        end
    end
    return false
end

local function isInsideToolOrCharacter(v)
    local p = v
    while p do
        if p:IsA("Tool") then
            return true
        end
        if p:IsA("Model") and Players:GetPlayerFromCharacter(p) then
            return true
        end
        p = p.Parent
    end
    return false
end

local function instanceVisible(v, depth)
    depth = depth or 0
    if not v or depth > 5 then
        return false
    end
    if v:IsA("BasePart") then
        if v.Transparency < 1 then
            return true
        end
    elseif v:IsA("Decal") or v:IsA("Texture") then
        if v.Transparency < 1 then
            return true
        end
    elseif v:IsA("SurfaceGui") or v:IsA("BillboardGui") then
        if v.Enabled then
            return true
        end
    elseif v:IsA("ImageLabel") or v:IsA("ImageButton") then
        if v.ImageTransparency < 1 and v.Visible then
            return true
        end
    elseif v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
        if v.TextTransparency < 1 and v.Visible then
            return true
        end
    elseif v:IsA("ParticleEmitter") or v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
        if v.Enabled then
            return true
        end
    elseif v:IsA("Beam") or v:IsA("Trail") then
        if v.Enabled then
            return true
        end
    elseif v:IsA("BoolValue") then
        if v.Value == true then
            return true
        end
    end
    for _, d in ipairs(v:GetDescendants()) do
        if instanceVisible(d, depth + 1) then
            return true
        end
    end
    return false
end

local function checkUVInContainer(root)
    if not root or uvEvidenceFired then
        return
    end
    for _, d in ipairs(root:GetDescendants()) do
        if matchesUVName(d.Name) and not isInsideToolOrCharacter(d) then
            if instanceVisible(d) then
                fireUVEvidence("UV-detected: " .. d:GetFullName():sub(1, 80))
                return
            end
        end
    end
end

task.spawn(function()
    local map = Workspace:WaitForChild("Map", 30)
    if not map then
        return
    end
    local prints = map:WaitForChild("Prints", 30)
    if prints then
        print("[SysHub] Hooked Map.Prints for UV detection")
        prints.DescendantAdded:Connect(function(d)
            if not autoEvidenceDetectActive or uvEvidenceFired then
                return
            end
            task.wait(0.05)
            if matchesUVName(d.Name) and instanceVisible(d) then
                fireUVEvidence("Map.Prints new: " .. d.Name)
            end
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if autoEvidenceDetectActive and not uvEvidenceFired then
            local map = Workspace:FindFirstChild("Map")
            if map then
                local prints = map:FindFirstChild("Prints")
                if prints then
                    checkUVInContainer(prints)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(8)
        if autoEvidenceDetectActive and not uvEvidenceFired then
            checkUVInContainer(Workspace)
        end
    end
end)

local uvLightToolsHooked = setmetatable({}, {__mode = "k"})
local function hookUVLightTool(t)
    if not t or uvLightToolsHooked[t] then
        return
    end
    if not t:IsA("Tool") or t.Name ~= "UV Light" then
        return
    end
    uvLightToolsHooked[t] = true
    pcall(function()
        t.Activated:Connect(function()
            task.wait(0.1)
            if autoEvidenceDetectActive and not uvEvidenceFired then
                local map = Workspace:FindFirstChild("Map")
                local prints = map and map:FindFirstChild("Prints")
                if prints then
                    checkUVInContainer(prints)
                end
            end
        end)
    end)
end

task.spawn(function()
    local function checkContainer(root)
        if not root then
            return
        end
        for _, v in ipairs(root:GetChildren()) do
            if v:IsA("Tool") and v.Name == "UV Light" then
                hookUVLightTool(v)
            end
        end
        root.ChildAdded:Connect(function(v)
            if v:IsA("Tool") and v.Name == "UV Light" then
                task.wait(0.1)
                hookUVLightTool(v)
            end
        end)
    end
    local bp = LocalPlayer:WaitForChild("Backpack", 30)
    checkContainer(bp)
    if LocalPlayer.Character then
        checkContainer(LocalPlayer.Character)
    end
    LocalPlayer.CharacterAdded:Connect(function(c)
        task.wait(0.5)
        checkContainer(c)
    end)
end)

if UVPartRemote and UVPartRemote:IsA("RemoteEvent") then
    UVPartRemote.OnClientEvent:Connect(function(...)
        if not autoEvidenceDetectActive then
            return
        end
        fireUVEvidence("UVPartInteraction remote")
    end)
end

-- ============================================================
-- SPIRIT BOX (v6.9.37 — check all players' spirit box)
-- ============================================================

local SPIRITBOX_QUESTION_TEXTS_NORM = {
    ["where are you"] = true,
    ["are you close"] = true,
    ["are you friendly"] = true,
}

local function normalizeForQuestionCheck(s)
    if type(s) ~= "string" then
        return nil
    end
    local low = s:lower()
    low = low:gsub("^%s+", ""):gsub("%s+$", "")
    low = low:gsub("[%?%!%.%,;:]+$", "")
    low = low:gsub("^[%?%!%.%,;:]+", "")
    low = low:gsub("%s+", " ")
    return low
end

local function isSpiritBoxQuestionText(txt)
    local norm = normalizeForQuestionCheck(txt)
    if not norm then
        return false
    end
    if SPIRITBOX_QUESTION_TEXTS_NORM[norm] then
        return true
    end
    return false
end

local SPIRITBOX_IGNORE = {
    ["turn"] = true, ["toggle"] = true, ["on"] = true, ["off"] = true;
    ["enable"] = true, ["disable"] = true, ["equip"] = true, ["unequip"] = true;
    ["ready"] = true, ["activate"] = true, ["deactivate"] = true;
    ["question"] = true, ["ask"] = true, ["open"] = true, ["close"] = true;
    ["start"] = true, ["stop"] = true, ["test"] = true;
    ["getTools"] = true, ["getFeatures"] = true, ["getPlayerEffects"] = true, ["getAchievements"] = true;
    ["are you close?"] = true; ["are you friendly?"] = true;
    ["where are you?"] = true;
    ["status"] = true; ["status: ok"] = true; ["status: err"] = true; ["status: error"] = true;
    ["ok"] = true; ["rec"] = true; ["loading"] = true; ["error"] = true;
    ["warning"] = true; ["camera"] = true; ["camera 1"] = true; ["camera 2"] = true;
    ["connected"] = true; ["disconnected"] = true; ["online"] = true; ["offline"] = true;
    ["ready to record"] = true; ["standby"] = true;
}

local SPIRIT_KEYWORDS = {
    ["death"] = true, ["dead"] = true, ["die"] = true, ["dies"] = true, ["dying"] = true, ["died"] = true, ["dieing"] = true;
    ["kill"] = true, ["kills"] = true, ["killing"] = true, ["killed"] = true;
    ["murder"] = true, ["murdered"] = true, ["murdering"] = true;
    ["run"] = true, ["running"] = true, ["ran"] = true, ["runs"] = true;
    ["hide"] = true, ["hiding"] = true, ["hides"] = true;
    ["breath"] = true, ["breathe"] = true, ["breathing"] = true, ["breaths"] = true;
    ["help me"] = true, ["help us"] = true, ["save me"] = true, ["save us"] = true;
    ["i see you"] = true, ["see you"] = true;
    ["stay away"] = true, ["go away"] = true;
    ["let me out"] = true, ["get out"] = true;
    ["i am here"] = true, ["im here"] = true;
    ["i am lost"] = true, ["im lost"] = true;
    ["you die"] = true, ["i die"] = true, ["will die"] = true, ["going to die"] = true;
    ["you will die"] = true, ["youre going to die"] = true;
    ["you killed"] = true, ["i killed"] = true;
    ["behind you"] = true; ["behind"] = true;
    ["helpme"] = true, ["helpus"] = true, ["saveme"] = true, ["saveus"] = true;
    ["iseeyou"] = true, ["seeyou"] = true, ["stayaway"] = true, ["goaway"] = true;
    ["letmeout"] = true, ["getout"] = true, ["iamhere"] = true, ["imhere"] = true;
    ["iamlost"] = true, ["imlost"] = true, ["youdie"] = true, ["idie"] = true;
    ["willdie"] = true, ["goingtodie"] = true, ["youwilldie"] = true, ["youregoingtodie"] = true;
    ["youkilled"] = true, ["ikilled"] = true;
    ["behindyou"] = true;
    ["help"] = true, ["save"] = true, ["blood"] = true, ["bloody"] = true;
    ["afraid"] = true, ["scared"] = true, ["fear"] = true;
    ["yes"] = true, ["no"] = true, ["maybe"] = true, ["never"] = true, ["always"] = true;
    ["hello"] = true, ["hi"] = true, ["hey"] = true, ["bye"] = true, ["goodbye"] = true;
    ["leave"] = true, ["leaving"] = true, ["stay"] = true;
    ["here"] = true, ["there"] = true, ["near"] = true, ["close"] = true;
    ["old"] = true, ["young"] = true, ["child"] = true, ["baby"] = true;
    ["male"] = true, ["female"] = true, ["man"] = true, ["woman"] = true, ["boy"] = true, ["girl"] = true;
    ["alone"] = true, ["cold"] = true, ["hot"] = true, ["dark"] = true, ["light"] = true;
    ["door"] = true, ["window"] = true, ["basement"] = true, ["attic"] = true;
    ["kitchen"] = true, ["bedroom"] = true, ["bathroom"] = true, ["garage"] = true, ["hall"] = true;
    ["why"] = true, ["what"] = true, ["where"] = true, ["who"] = true, ["how"] = true;
}

local NOISE_PATH_FRAGMENTS = {
    "ToolBarGui",
    "ItemPreview",
    "ToolViewport",
    "ZoneBillboard",
    "SpawnPointBillboard",
}

local NOISE_NAME_EXACT = {
    "ButtonA", "ButtonB", "ButtonC", "RoomName",
}

local function isNoiseSource(v)
    local directName = v.Name or ""
    for _, nm in ipairs(NOISE_NAME_EXACT) do
        if directName == nm then
            return true
        end
    end
    local p, depth = v, 0
    while p and depth < 12 do
        local n = p.Name or ""
        for _, frag in ipairs(NOISE_PATH_FRAGMENTS) do
            if n == frag or n:find(frag, 1, true) then
                return true
            end
        end
        p = p.Parent
        depth = depth + 1
    end
    return false
end

local function extractStrings(v, depth, out)
    depth = depth or 0
    out = out or {}
    if depth > 4 then
        return out
    end
    local t = type(v)
    if t == "string" then
        table.insert(out, v)
    elseif t == "table" then
        for k, vv in pairs(v) do
            extractStrings(vv, depth + 1, out)
            if type(k) == "string" then
                extractStrings(k, depth + 1, out)
            end
        end
    elseif typeof(v) == "Instance" then
        if v:IsA("StringValue") then
            table.insert(out, v.Value)
        elseif v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
            table.insert(out, v.Text)
        end
    end
    return out
end

local function sanitizeSpiritString(s)
    if type(s) ~= "string" then
        return nil
    end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("^[%p]+", ""):gsub("[%p]+$", "")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if #s < 2 then
        return nil
    end
    return s
end

local function testSpiritString(s)
    if type(s) ~= "string" then
        return false
    end
    local cleaned = sanitizeSpiritString(s)
    if not cleaned then
        return false
    end
    if #cleaned > 60 then
        return false
    end
    if cleaned:match("^[%d%.%s%-]+$") then
        return false
    end
    local low = cleaned:lower()
    if SPIRITBOX_IGNORE[low] then
        return false
    end
    if low:find("[%[%]{}<>@#%$%%%^&%*_=+|\\/]") then
        return false
    end
    if low:find("spiritbox") or low:find("spirit box") then
        return false
    end
    if SPIRIT_KEYWORDS[low] then
        return true
    end
    local nospace = low:gsub("%s+", "")
    if SPIRIT_KEYWORDS[nospace] then
        return true
    end
    local lettersOnly = low:gsub("[^%a]", "")
    if #lettersOnly >= 2 and #lettersOnly <= 20 and SPIRIT_KEYWORDS[lettersOnly] then
        return true
    end
    for kw in pairs(SPIRIT_KEYWORDS) do
        if #kw >= 4 and kw:find(" ", 1, true) then
            if low:find(kw, 1, true) then
                return true
            end
        end
    end
    for kw in pairs(SPIRIT_KEYWORDS) do
        if #kw >= 4 and not kw:find(" ", 1, true) then
            local ok, found = pcall(function()
                return low:find("%f[%a]" .. kw .. "%f[%A]")
            end)
            if ok and found then
                return true
            end
        end
    end
    return false
end

-- ============================================================
-- Equipped gate (v6.9.37: cek SEMUA PEMAIN)
-- ============================================================
local lastSpiritBoxEquippedTime = 0

local function isSpiritBoxEquippedByAnyone()
    -- Cek LocalPlayer
    local char = LocalPlayer.Character
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") and (v.Name == "Spirit Box" or v.Name == "SpiritBox") then
                lastSpiritBoxEquippedTime = tick()
                return true
            end
        end
    end
    -- Cek semua pemain lain
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local c = plr.Character
            if c then
                for _, v in ipairs(c:GetChildren()) do
                    if v:IsA("Tool") and (v.Name == "Spirit Box" or v.Name == "SpiritBox") then
                        lastSpiritBoxEquippedTime = tick()
                        return true
                    end
                end
            end
        end
    end
    return false
end

local SPIRITBOX_GRACE_PERIOD = 5
local function isSpiritBoxActive()
    if isSpiritBoxEquippedByAnyone() then
        return true
    end
    if lastSpiritBoxEquippedTime > 0 and (tick() - lastSpiritBoxEquippedTime) < SPIRITBOX_GRACE_PERIOD then
        return true
    end
    return false
end

-- ============================================================
-- Source check
-- ============================================================
local SOURCE_HINTS = {
    "spiritbox", "spirit_box", "spiritboxui",
    "spiritresponse", "spirit_response", "spiritvoice", "spirit_voice",
    "ghostresponse", "ghost_response", "ghosttext", "ghost_text",
    "responsetext", "response_text",
}

local function sourceMatches(v)
    local p, depth = v, 0
    while p and depth < 6 do
        local n = (p.Name or ""):lower()
        for _, kw in ipairs(SOURCE_HINTS) do
            if n == kw or n:find(kw, 1, true) then
                return true
            end
        end
        p = p.Parent
        depth = depth + 1
    end
    return false
end

local function handleSpiritBoxEvent(sourceName, ...)
    if not autoEvidenceDetectActive then
        return
    end
    if not isSpiritBoxActive() then
        print("[SysHub][Spirit] Blocked (no Spirit Box equipped anywhere): " .. tostring(sourceName))
        return
    end
    local args = {...}
    local allStrings = {}
    for _, a in ipairs(args) do
        extractStrings(a, 0, allStrings)
    end
    for _, s in ipairs(allStrings) do
        if isSpiritBoxQuestionText(s) then
            return
        end
        if testSpiritString(s) then
            print("[SysHub] SpiritBox [" .. tostring(sourceName) .. "] -> " .. s)
            addDetectedEvidence("Spirit Box")
            return
        end
    end
end

-- ============================================================
-- SOUND DETECTION — WHITELIST GhostTalk/GhostVoice only
-- ============================================================
local hookedSpiritSounds = setmetatable({}, {__mode = "k"})

local SPIRIT_RESPONSE_WHITELIST = {
    "ghosttalk", "ghost_talk", "ghost talk",
    "ghostvoice", "ghost_voice", "ghost voice",
    "ghostresponse", "ghost_response", "ghost response",
    "spiritvoice", "spirit_voice", "spirit voice",
    "spiritresponse", "spirit_response", "spirit response",
    "spiritanswer", "spirit_answer", "spirit answer",
}

local function isGhostResponseSound(s)
    if not s or not s:IsA("Sound") then
        return false
    end
    local n = (s.Name or ""):lower()
    for _, hint in ipairs(SPIRIT_RESPONSE_WHITELIST) do
        if n:find(hint, 1, true) then
            return true
        end
    end
    return false
end

local SPIRIT_TOOL_SFX_EXCLUDE = {
    "interactsfx", "interact_sfx", "interact",
    "static", "click", "press", "tap",
    "turnon", "turn_on", "turnoff", "turn_off", "turn on", "turn off",
    "activate", "deactivate", "equip", "unequip",
    "toggle", "switch", "power", "startup", "shutdown", "beep",
    "close", "near", "far", "nexttoyou", "rightbyou", "behindyou",
    "on", "off",
}

local function isExcludedToolSFX(name)
    if type(name) ~= "string" or #name == 0 then
        return false
    end
    local n = name:lower()
    for _, ex in ipairs(SPIRIT_TOOL_SFX_EXCLUDE) do
        if n == ex then
            return true
        end
    end
    return false
end

local function fireSpiritBoxFromSound(s)
    if not autoEvidenceDetectActive then
        return
    end
    if not isSpiritBoxActive() then
        print("[SysHub][Spirit] Sound blocked (no Spirit Box equipped anywhere): " .. s.Name)
        return
    end
    if not isGhostResponseSound(s) then
        print("[SysHub][Spirit] Sound skipped (not ghost response): " .. s.Name)
        return
    end
    if isExcludedToolSFX(s.Name) then
        print("[SysHub][Spirit] Sound excluded (tool SFX name): " .. s.Name)
        return
    end
    print("[SysHub] SpiritBox [Sound:" .. s:GetFullName() .. "] -> FIRING (name='" .. s.Name .. "')")
    addDetectedEvidence("Spirit Box")
end

local function hookSpiritSound(s)
    if not s or not s:IsA("Sound") or hookedSpiritSounds[s] then
        return
    end
    hookedSpiritSounds[s] = true
    print("[SysHub][Spirit] Hooked sound: " .. s:GetFullName() .. " (name='" .. s.Name .. "')")
    pcall(function()
        s:GetPropertyChangedSignal("Playing"):Connect(function()
            if s.Playing then
                print("[SysHub][Spirit] Sound PLAY: " .. s.Name)
                fireSpiritBoxFromSound(s)
            end
        end)
    end)
    pcall(function()
        s.Played:Connect(function()
            print("[SysHub][Spirit] Sound PLAYED: " .. s.Name)
            fireSpiritBoxFromSound(s)
        end)
    end)
end

local function scanSpiritSounds(root)
    if not root then
        return
    end
    local count = 0
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("Sound") then
            hookSpiritSound(d)
            count = count + 1
        end
    end
    print("[SysHub][Spirit] Scanned " .. count .. " sounds in " .. (root:GetFullName()):sub(1, 80))
    root.DescendantAdded:Connect(function(d)
        if d:IsA("Sound") then
            hookSpiritSound(d)
        end
    end)
end

task.spawn(function()
    local map = Workspace:WaitForChild("Map", 30)
    if not map then
        return
    end
    local items = map:FindFirstChild("Items")
    if items then
        local sb = items:FindFirstChild("Spirit Box") or items:FindFirstChild("SpiritBox")
        if sb then
            scanSpiritSounds(sb)
            print("[SysHub][Spirit] Scanned Map.Items.Spirit Box")
        end
    end
end)

local function scanPlayerForSpiritBox(plr)
    if not plr then
        return
    end
    local function scanChar(ch)
        if not ch then
            return
        end
        for _, t in ipairs(ch:GetChildren()) do
            if t:IsA("Tool") and (t.Name == "Spirit Box" or t.Name == "SpiritBox") then
                scanSpiritSounds(t)
            end
        end
        ch.ChildAdded:Connect(function(t)
            task.wait(0.1)
            if t:IsA("Tool") and (t.Name == "Spirit Box" or t.Name == "SpiritBox") then
                scanSpiritSounds(t)
            end
        end)
    end
    if plr.Character then
        scanChar(plr.Character)
    end
    plr.CharacterAdded:Connect(function(ch)
        task.wait(1)
        scanChar(ch)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    scanPlayerForSpiritBox(plr)
end
Players.PlayerAdded:Connect(scanPlayerForSpiritBox)

task.spawn(function()
    while true do
        task.wait(3)
        for _, plr in ipairs(Players:GetPlayers()) do
            local bp = plr:FindFirstChild("Backpack")
            if bp then
                for _, t in ipairs(bp:GetChildren()) do
                    if t:IsA("Tool") and (t.Name == "Spirit Box" or t.Name == "SpiritBox") then
                        if not hookedSpiritSounds[t] then
                            for _, d in ipairs(t:GetDescendants()) do
                                if d:IsA("Sound") then
                                    hookSpiritSound(d)
                                end
                            end
                            hookedSpiritSounds[t] = true
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- BUTTON CLICK tracking
-- ============================================================
local hookedButtons = setmetatable({}, {__mode = "k"})

local function hookSpiritBoxButton(btn)
    if not btn or hookedButtons[btn] then
        return
    end
    if not btn:IsA("TextButton") and not btn:IsA("ImageButton") then
        return
    end
    hookedButtons[btn] = true
    pcall(function()
        btn.Activated:Connect(function()
            print("[SysHub][Spirit] Question clicked: " .. btn:GetFullName())
        end)
    end)
    pcall(function()
        btn.MouseButton1Click:Connect(function()
            print("[SysHub][Spirit] Question clicked: " .. btn:GetFullName())
        end)
    end)
end

task.spawn(function()
    local map = Workspace:WaitForChild("Map", 30)
    if not map then
        return
    end
    local items = map:FindFirstChild("Items")
    if items then
        local sb = items:FindFirstChild("Spirit Box") or items:FindFirstChild("SpiritBox")
        if sb then
            for _, d in ipairs(sb:GetDescendants()) do
                if d:IsA("TextButton") or d:IsA("ImageButton") then
                    hookSpiritBoxButton(d)
                end
            end
            sb.DescendantAdded:Connect(function(d)
                task.wait(0.05)
                if d:IsA("TextButton") or d:IsA("ImageButton") then
                    hookSpiritBoxButton(d)
                end
            end)
        end
    end
end)

task.spawn(function()
    local board = Workspace:WaitForChild("Spirit Board", 20)
    if not board then
        return
    end
    local uiQuestion = board:FindFirstChild("UIQuestion")
    if uiQuestion and uiQuestion:IsA("RemoteEvent") and not hookedRemotes[uiQuestion] then
        hookedRemotes[uiQuestion] = true
        uiQuestion.OnClientEvent:Connect(function(...)
            handleSpiritBoxEvent("SpiritBoard:UIQuestion", ...)
        end)
        print("[SysHub] Hooked Spirit Board.UIQuestion")
    end
    local activated = board:FindFirstChild("ActivatedStateChanged")
    if activated and activated:IsA("RemoteEvent") and not hookedRemotes[activated] then
        hookedRemotes[activated] = true
        activated.OnClientEvent:Connect(function(...)
            handleSpiritBoxEvent("SpiritBoard:ActivatedStateChanged", ...)
        end)
    end
end)

local watchedFloatingTexts = setmetatable({}, {__mode = "k"})

local function isFloatingText3D(v)
    local p = v
    local hasGui = false
    while p do
        if p:IsA("PlayerGui") then
            return false
        end
        if p:IsA("BillboardGui") or p:IsA("SurfaceGui") then
            hasGui = true
        end
        if p == Workspace then
            return hasGui
        end
        p = p.Parent
    end
    return false
end

local function watchFloatingText(v)
    if not v or watchedFloatingTexts[v] then
        return
    end
    if not v:IsA("TextLabel") and not v:IsA("TextButton") and not v:IsA("TextBox") then
        return
    end
    watchedFloatingTexts[v] = true

    local function checkText(txt)
        if type(txt) ~= "string" or #txt == 0 then
            return
        end
        if isNoiseSource(v) then
            return
        end
        if isSpiritBoxQuestionText(txt) then
            return
        end
        local cleaned = sanitizeSpiritString(txt)
        if not cleaned then
            return
        end
        if not testSpiritString(cleaned) then
            return
        end
        if isFloatingText3D(v) or sourceMatches(v) then
            print("[SysHub][Spirit] Text candidate: '" .. cleaned .. "' @ " .. v:GetFullName())
            handleSpiritBoxEvent("Text:" .. v.Name, txt)
        end
    end

    if v.Text and #v.Text > 0 then
        pcall(checkText, v.Text)
    end
    task.spawn(function()
        task.wait(0.4)
        if v.Parent and v.Text and #v.Text > 0 then
            pcall(checkText, v.Text)
        end
    end)

    pcall(function()
        v:GetPropertyChangedSignal("Text"):Connect(function()
            checkText(v.Text)
        end)
    end)
end

local scannedRoots = setmetatable({}, {__mode = "k"})

local function scanAllTexts(root)
    if not root then
        return
    end
    for _, v in ipairs(root:GetDescendants()) do
        if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
            watchFloatingText(v)
        end
    end
    if not scannedRoots[root] then
        scannedRoots[root] = true
        pcall(function()
            root.DescendantAdded:Connect(function(d)
                task.wait(0.1)
                if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                    watchFloatingText(d)
                end
            end)
        end)
    end
end

task.spawn(function()
    scanAllTexts(Workspace)
    local pg = LocalPlayer:WaitForChild("PlayerGui", 15)
    if pg then
        scanAllTexts(pg)
    end
    print("[SysHub] Watching floating TextLabels")
end)

if TypewriteRemote and TypewriteRemote:IsA("RemoteEvent") and not hookedRemotes[TypewriteRemote] then
    hookedRemotes[TypewriteRemote] = true
    TypewriteRemote.OnClientEvent:Connect(function(...)
        handleSpiritBoxEvent("Typewrite", ...)
    end)
end

if PrintOnClientRemote and PrintOnClientRemote:IsA("RemoteEvent") and not hookedRemotes[PrintOnClientRemote] then
    hookedRemotes[PrintOnClientRemote] = true
    PrintOnClientRemote.OnClientEvent:Connect(function(...)
        handleSpiritBoxEvent("PrintOnClient", ...)
    end)
end

if PrintStringOnClientRemote and PrintStringOnClientRemote:IsA("RemoteEvent") and not hookedRemotes[PrintStringOnClientRemote] then
    hookedRemotes[PrintStringOnClientRemote] = true
    PrintStringOnClientRemote.OnClientEvent:Connect(function(...)
        handleSpiritBoxEvent("PrintStringOnClient", ...)
    end)
end

task.spawn(function()
    if not Remotes then
        return
    end
    local HINT_NAMES = {
        "ghostresponse", "spiritresponse", "spirittext", "ghosttext",
        "responsetext", "spiritvoice",
    }
    local function tryHook(r)
        if not r or not r:IsA("RemoteEvent") then
            return
        end
        if hookedRemotes[r] then
            return
        end
        local n = r.Name:lower()
        for _, hint in ipairs(HINT_NAMES) do
            if n == hint then
                hookedRemotes[r] = true
                r.OnClientEvent:Connect(function(...)
                    handleSpiritBoxEvent("Remote:" .. r.Name, ...)
                end)
                print("[SysHub] Hooked response remote: " .. r.Name)
                return
            end
        end
    end
    for _, r in ipairs(Remotes:GetChildren()) do
        tryHook(r)
    end
    Remotes.ChildAdded:Connect(function(r)
        task.wait(0.05)
        tryHook(r)
    end)
end)

local function isSpiritBoxTool(t)
    if not t or not t:IsA("Tool") then
        return false
    end
    local n = t.Name:lower()
    return n == "spirit box" or n == "spiritbox"
end

local function hookSpiritBoxTool(t)
    if not t or hookedTools[t] then
        return
    end
    hookedTools[t] = true
    for _, v in ipairs(t:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            if not hookedRemotes[v] then
                hookedRemotes[v] = true
                v.OnClientEvent:Connect(function(...)
                    handleSpiritBoxEvent("Tool:" .. v.Name, ...)
                end)
            end
        elseif v:IsA("Sound") then
            hookSpiritSound(v)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(2)
        local map = Workspace:FindFirstChild("Map")
        if map then
            local items = map:FindFirstChild("Items")
            if items then
                for _, v in ipairs(items:GetDescendants()) do
                    if isSpiritBoxTool(v) then
                        hookSpiritBoxTool(v)
                    end
                end
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            local bp = plr:FindFirstChild("Backpack")
            if bp then
                for _, v in ipairs(bp:GetChildren()) do
                    if isSpiritBoxTool(v) then
                        hookSpiritBoxTool(v)
                    end
                end
            end
            local ch = plr.Character
            if ch then
                for _, v in ipairs(ch:GetChildren()) do
                    if isSpiritBoxTool(v) then
                        hookSpiritBoxTool(v)
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- EVIDENCE HOOKS (EMF, Thermometer, Book, UV)
-- ============================================================
local function hookBoolValue(bv, evidence)
    if not bv or not bv:IsA("BoolValue") or hookedValueObjects[bv] then
        return
    end
    hookedValueObjects[bv] = true
    if bv.Value then
        addDetectedEvidence(evidence)
    end
    bv:GetPropertyChangedSignal("Value"):Connect(function()
        if bv.Value then
            addDetectedEvidence(evidence)
        end
    end)
end

local function hookNumberValue(nv, callback)
    if not nv or not nv:IsA("NumberValue") or hookedValueObjects[nv] then
        return
    end
    hookedValueObjects[nv] = true
    nv:GetPropertyChangedSignal("Value"):Connect(function()
        callback(nv.Value)
    end)
end

local function hookEMF(t)
    if not t or hookedTools[t] then
        return
    end
    hookedTools[t] = true
    for _, v in ipairs(t:GetDescendants()) do
        if v:IsA("BoolValue") then
            local n = v.Name:lower()
            if n:find("levelfive") or n:find("level5") or n:find("level_five") or n:find("emf5") then
                hookBoolValue(v, "EMF Level 5")
            end
        elseif v:IsA("NumberValue") then
            local n = v.Name:lower()
            if n:find("level") or n:find("emf") then
                hookNumberValue(v, function(val)
                    if typeof(val) == "number" and val >= 5 then
                        addDetectedEvidence("EMF Level 5")
                    end
                end)
            end
        end
    end
    pcall(function()
        t:GetAttributeChangedSignal("RecentlyLevelFive"):Connect(function()
            if t:GetAttribute("RecentlyLevelFive") == true then
                addDetectedEvidence("EMF Level 5")
            end
        end)
    end)
end

local function hookThermometer(t)
    if not t or hookedTools[t] then
        return
    end
    hookedTools[t] = true
    for _, v in ipairs(t:GetDescendants()) do
        if v:IsA("BoolValue") and v.Name:lower():find("freez") then
            hookBoolValue(v, "Freezing Temperatures")
        elseif v:IsA("NumberValue") and (v.Name:lower():find("temp") or v.Name:lower():find("freez")) then
            hookNumberValue(v, function(val)
                if typeof(val) == "number" then
                    refreshAutoStatusUI()
                end
            end)
        end
    end
end

local function hookBook(t)
    if not t or hookedTools[t] then
        return
    end
    hookedTools[t] = true
    for _, v in ipairs(t:GetDescendants()) do
        if v:IsA("BoolValue") and v.Name:lower():find("writ") then
            hookBoolValue(v, "Ghost Writing")
        end
    end
    pcall(function()
        t:GetAttributeChangedSignal("Written"):Connect(function()
            if t:GetAttribute("Written") == true then
                addDetectedEvidence("Ghost Writing")
            end
        end)
    end)
end

local function hookUVLight(t)
    if not t or hookedTools[t] then
        return
    end
    hookedTools[t] = true
end

local sniffed = setmetatable({}, {__mode = "k"})

local function sniffInstance(v)
    if not v or sniffed[v] then
        return
    end
    if v:IsA("BoolValue") then
        if hookedValueObjects[v] then
            sniffed[v] = true
            return
        end
        sniffed[v] = true
        hookedValueObjects[v] = true
        local function check()
            if v.Value then
                local ev = detectEvidenceFromString(v.Name)
                if not ev and v.Parent then
                    ev = detectEvidenceFromString(v.Parent.Name)
                end
                if ev then
                    addDetectedEvidence(ev)
                end
            end
        end
        if v.Value then
            check()
        end
        v:GetPropertyChangedSignal("Value"):Connect(check)
    elseif v:IsA("StringValue") then
        if hookedValueObjects[v] then
            sniffed[v] = true
            return
        end
        sniffed[v] = true
        hookedValueObjects[v] = true
        local function check()
            local ev = detectEvidenceFromString(v.Value) or detectEvidenceFromString(v.Name)
            if ev then
                addDetectedEvidence(ev)
            end
        end
        if v.Value ~= "" then
            check()
        end
        v:GetPropertyChangedSignal("Value"):Connect(check)
    elseif v:IsA("NumberValue") then
        if hookedValueObjects[v] then
            sniffed[v] = true
            return
        end
        sniffed[v] = true
        hookedValueObjects[v] = true
        v:GetPropertyChangedSignal("Value"):Connect(function()
            if not autoEvidenceDetectActive then
                return
            end
            local n, val = v.Name:lower(), v.Value
            if typeof(val) ~= "number" then
                return
            end
            if (n:find("level") or n:find("emf")) and val >= 5 then
                addDetectedEvidence("EMF Level 5")
            end
        end)
    else
        local ok, attrs = pcall(function()
            return v:GetAttributes()
        end)
        if not ok or not attrs then
            return
        end
        local hasRelevant = false
        for name, val in pairs(attrs) do
            if detectEvidenceFromString(name) then
                hasRelevant = true
                break
            end
            if type(val) == "string" and detectEvidenceFromString(val) then
                hasRelevant = true
                break
            end
        end
        if not hasRelevant then
            return
        end
        sniffed[v] = true
        v.AttributeChanged:Connect(function(name)
            if not autoEvidenceDetectActive then
                return
            end
            local val = v:GetAttribute(name)
            local ev = detectEvidenceFromString(name)
            if ev and (val == true or (type(val) == "number" and val > 0)) then
                addDetectedEvidence(ev)
            end
        end)
    end
end

local function sniffContainer(root, maxDepth)
    if not root then
        return
    end
    maxDepth = maxDepth or 3
    local function walk(inst, depth)
        if depth > maxDepth then
            return
        end
        sniffInstance(inst)
        for _, c in ipairs(inst:GetChildren()) do
            walk(c, depth + 1)
        end
    end
    pcall(walk, root, 0)
end

do
    sniffContainer(LocalPlayer:FindFirstChild("Backpack"), 3)
    if LocalPlayer.Character then
        sniffContainer(LocalPlayer.Character, 3)
    end
    local map = Workspace:FindFirstChild("Map")
    if map then
        local items = map:FindFirstChild("Items")
        if items then
            sniffContainer(items, 3)
        end
        local zones = map:FindFirstChild("Zones")
        if zones then
            sniffContainer(zones, 3)
        end
    end
end

local function hookToolByName(t)
    if not t or hookedTools[t] then
        return
    end
    local n = t.Name
    if n == "EMF Reader" or n == "EMF" then
        hookEMF(t)
    elseif n == "Thermometer" or n == "Temperature Meter" then
        hookThermometer(t)
    elseif n == "Ghost Writing Book" or n == "Writing Book" then
        hookBook(t)
    elseif isSpiritBoxTool(t) then
        hookSpiritBoxTool(t)
    elseif n == "UV Light" then
        hookUVLight(t)
        hookUVLightTool(t)
    end
    sniffInstance(t)
end

task.spawn(function()
    local map = Workspace:WaitForChild("Map", 30)
    if not map then
        return
    end
    local items = map:WaitForChild("Items", 30)
    if not items then
        return
    end
    for _, v in ipairs(items:GetChildren()) do
        if v:IsA("Tool") then
            hookToolByName(v)
        end
    end
    items.ChildAdded:Connect(function(v)
        if v:IsA("Tool") then
            task.wait(0.05)
            hookToolByName(v)
        end
    end)
end)

task.spawn(function()
    local bp = LocalPlayer:WaitForChild("Backpack", 30)
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") then
                hookToolByName(v)
            end
        end
        bp.ChildAdded:Connect(function(v)
            if v:IsA("Tool") then
                task.wait(0.05)
                hookToolByName(v)
            end
        end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(2)
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("Tool") then
            hookToolByName(v)
        end
    end
    sniffContainer(c, 3)
end)

local promptCache = setmetatable({}, {__mode = "k"})

local function applyInstantInteract(p)
    if not p:IsA("ProximityPrompt") or promptCache[p] then
        return
    end
    promptCache[p] = p.HoldDuration
    if p.HoldDuration > 0 then
        p.HoldDuration = 0
    end
end

local function restoreInstantInteract()
    for p, origHold in pairs(promptCache) do
        if p.Parent then
            pcall(function()
                p.HoldDuration = origHold
            end)
        end
    end
    promptCache = setmetatable({}, {__mode = "k"})
end

local PromptConn = nil

local function enablePromptWatcher()
    if PromptConn then
        return
    end
    PromptConn = Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("ProximityPrompt") then
            applyInstantInteract(d)
        end
    end)
end

local function disablePromptWatcher()
    if PromptConn then
        PromptConn:Disconnect()
        PromptConn = nil
    end
end

local StaminaNumberValues, StaminaAttrTargets = {}, {}
local LastStaminaScan = 0

local function isStaminaName(name)
    local n = (name or ""):lower()
    return n:find("stam") or n:find("sprint") or n:find("energybar") or n:find("energy_bar")
end

local function scanStaminaAll()
    StaminaNumberValues, StaminaAttrTargets = {}, {}
    local roots = {LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack")}
    for _, root in ipairs(roots) do
        if root then
            for _, v in ipairs(root:GetDescendants()) do
                if v:IsA("NumberValue") and isStaminaName(v.Name) then
                    StaminaNumberValues[v] = v.Value
                end
            end
        end
    end
    local attrTargets = {LocalPlayer}
    if LocalPlayer.Character then
        table.insert(attrTargets, LocalPlayer.Character)
    end
    for _, inst in ipairs(attrTargets) do
        for name, val in pairs(inst:GetAttributes()) do
            if type(val) == "number" and isStaminaName(name) then
                table.insert(StaminaAttrTargets, {inst = inst, name = name, max = val})
            end
        end
    end
end

local function forceStamina()
    for nv, maxVal in pairs(StaminaNumberValues) do
        if nv.Parent and nv.Value < maxVal then
            nv.Value = maxVal
        end
    end
    for _, t in ipairs(StaminaAttrTargets) do
        local cur = t.inst:GetAttribute(t.name)
        if type(cur) == "number" and cur < t.max then
            pcall(function()
                t.inst:SetAttribute(t.name, t.max)
            end)
        end
    end
end

task.spawn(function()
    local bindables = ReplicatedStorage:FindFirstChild("Bindables")
    local drain = bindables and bindables:FindFirstChild("DrainSprintStamina")
    if drain and drain:IsA("RemoteEvent") then
        drain.OnClientEvent:Connect(function()
            if infiniteStaminaEnabled then
                forceStamina()
            end
        end)
    elseif drain and drain:IsA("BindableEvent") then
        drain.Event:Connect(function()
            if infiniteStaminaEnabled then
                forceStamina()
            end
        end)
    end
end)

task.spawn(function()
    while true do
        if infiniteStaminaEnabled then
            local now = tick()
            if now - LastStaminaScan > 3 then
                LastStaminaScan = now
                pcall(scanStaminaAll)
            end
        end
        task.wait(0.5)
    end
end)

RunService.Heartbeat:Connect(function()
    if not infiniteStaminaEnabled then
        return
    end
    forceStamina()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
    if sprinting then
        local sprintWS = capturedSprintSpeed or (originalWalkSpeed and originalWalkSpeed * 1.5) or 19
        if customWalkSpeedEnabled and targetWalkSpeed > sprintWS then
            sprintWS = targetWalkSpeed
        end
        if hum.WalkSpeed < sprintWS - 0.5 then
            hum.WalkSpeed = sprintWS
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.15)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and originalWalkSpeed then
            local ws = hum.WalkSpeed
            if ws > originalWalkSpeed + 2 and ws < 100 and (not capturedSprintSpeed or ws > capturedSprintSpeed) then
                capturedSprintSpeed = ws
            end
        end
    end
end)

local WalkSpeedConn = nil

local function attachWalkSpeed(char)
    if WalkSpeedConn then
        WalkSpeedConn:Disconnect()
    end
    WalkSpeedConn = nil
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then
        return
    end
    if not originalWalkSpeed then
        originalWalkSpeed = hum.WalkSpeed
    end
    if not customWalkSpeedEnabled and originalWalkSpeed then
        hum.WalkSpeed = originalWalkSpeed
    end
    WalkSpeedConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if originalWalkSpeed then
            local ws = hum.WalkSpeed
            if ws > originalWalkSpeed + 2 and ws < 100 and (not capturedSprintSpeed or ws > capturedSprintSpeed) then
                capturedSprintSpeed = ws
            end
        end
        if customWalkSpeedEnabled and not infiniteStaminaEnabled and hum.WalkSpeed ~= targetWalkSpeed then
            hum.WalkSpeed = targetWalkSpeed
        end
    end)
end

if LocalPlayer.Character then
    attachWalkSpeed(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(0.3)
    attachWalkSpeed(c)
end)

-- ============================================================
-- WalkSpeed Continuous Enforcement
-- ============================================================
RunService.RenderStepped:Connect(function()
    if not customWalkSpeedEnabled then
        return
    end
    local char = LocalPlayer.Character
    if not char then
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    if infiniteStaminaEnabled then
        local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        if sprinting then
            return
        end
    end
    if hum.WalkSpeed ~= targetWalkSpeed then
        hum.WalkSpeed = targetWalkSpeed
    end
end)

local NoclipConn, CachedParts, CacheTick = nil, {}, 0
local OrigCollide = setmetatable({}, {__mode = "k"})

local function refreshNoclipCache()
    local char = LocalPlayer.Character
    if not char then
        CachedParts = {}
        return
    end
    local list = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            if OrigCollide[p] == nil then
                OrigCollide[p] = p.CanCollide
            end
            table.insert(list, p)
        end
    end
    CachedParts = list
end

local function enableNoclip()
    if NoclipConn then
        NoclipConn:Disconnect()
    end
    refreshNoclipCache()
    CacheTick = tick()
    NoclipConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then
            return
        end
        if tick() - CacheTick > 2 then
            refreshNoclipCache()
            CacheTick = tick()
        end
        for _, p in ipairs(CachedParts) do
            if p.Parent and p.CanCollide then
                p.CanCollide = false
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum:GetState() == Enum.HumanoidStateType.Climbing then
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end)
end

local function disableNoclip()
    if NoclipConn then
        NoclipConn:Disconnect()
    end
    NoclipConn = nil
    for p, o in pairs(OrigCollide) do
        if p.Parent then
            pcall(function()
                p.CanCollide = o
            end)
        end
    end
    OrigCollide = setmetatable({}, {__mode = "k"})
    CachedParts = {}
end

local function teleportTo(cf)
    if not cf then
        return false
    end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    hrp.CFrame = cf
    task.spawn(function()
        task.wait(0.05)
        if hrp.Parent then
            hrp.CFrame = cf
        end
        task.wait(0.05)
        if hrp.Parent then
            hrp.CFrame = cf
        end
    end)
    return true
end

local function findVanCFrame()
    local map = Workspace:FindFirstChild("Map")
    local van = (map and map:FindFirstChild("Van")) or Workspace:FindFirstChild("IntroVan") or Workspace:FindFirstChild("Van")
    if not van then
        return nil
    end
    local core = van:FindFirstChild("CoreElements")
    if core then
        local sp = core:FindFirstChild("SpawnLocation")
        if sp and sp:IsA("BasePart") then
            return sp.CFrame + Vector3.new(0, 3, 0)
        end
    end
    local sp2 = van:FindFirstChild("SpawnLocation", true)
    if sp2 and sp2:IsA("BasePart") then
        return sp2.CFrame + Vector3.new(0, 3, 0)
    end
    local seat = van:FindFirstChildWhichIsA("VehicleSeat", true) or van:FindFirstChildWhichIsA("Seat", true)
    if seat then
        return seat.CFrame + Vector3.new(0, 3, 0)
    end
    local p = van:FindFirstChildWhichIsA("BasePart", true)
    if p then
        return p.CFrame + Vector3.new(0, 4, 0)
    end
    return nil
end

local function findGeneratorCFrame()
    local map = Workspace:FindFirstChild("Map")
    local gf = map and map:FindFirstChild("Generators")
    if gf then
        local p = gf:FindFirstChildWhichIsA("BasePart", true)
        if p then
            return p.CFrame + Vector3.new(0, 1.5, 2.5)
        end
    end
    return nil
end

local espFolder = Instance.new("Folder")
espFolder.Name = "SysHub_ESP_Holder"
pcall(function()
    espFolder.Parent = game:GetService("CoreGui")
end)
if not espFolder.Parent then
    espFolder.Parent = Workspace
end

local espTrackers = {Ghost = {}, GhostRoom = {}, Cursed = {}, BooBoo = {}, Breaker = {}, Teammates = {}}
local espEnabled = {Ghost = false, GhostRoom = false, Cursed = false, BooBoo = false, Breaker = false, Teammates = false}

local function clearESP(tag)
    if not espTrackers[tag] then
        return
    end
    for _, item in pairs(espTrackers[tag]) do
        pcall(function()
            if item.Highlight then
                item.Highlight:Destroy()
            end
            if item.Billboard then
                item.Billboard:Destroy()
            end
        end)
    end
    espTrackers[tag] = {}
end

local function removeESPSingle(tag, target)
    local e = espTrackers[tag] and espTrackers[tag][target]
    if not e then
        return
    end
    pcall(function()
        if e.Highlight then
            e.Highlight:Destroy()
        end
        if e.Billboard then
            e.Billboard:Destroy()
        end
    end)
    espTrackers[tag][target] = nil
end

local function addESP(tag, target, root, baseText, color)
    if not target or not root then
        return
    end
    if not espTrackers[tag] then
        espTrackers[tag] = {}
    end
    if espTrackers[tag][target] then
        local e = espTrackers[tag][target]
        e.baseText = baseText
        e.color = color
        if e.Highlight then
            e.Highlight.FillColor = color
        end
        if e.Label then
            e.Label.TextColor3 = color
        end
        if e.Billboard and e.Billboard.Adornee ~= root then
            e.Billboard.Adornee = root
        end
        return
    end
    local h = Instance.new("Highlight")
    h.Name = "SysESP_" .. tag
    h.Adornee = target
    h.FillColor = color
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0.1
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = espFolder
    local b = Instance.new("BillboardGui")
    b.Name = "SysESP_BB_" .. tag
    b.Adornee = root
    b.AlwaysOnTop = true
    b.Size = UDim2.fromOffset(200, 42)
    b.StudsOffset = Vector3.new(0, 3, 0)
    b.MaxDistance = 500
    b.Parent = espFolder
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0.2
    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.Text = baseText
    lbl.Parent = b
    espTrackers[tag][target] = {Highlight = h, Billboard = b, Label = lbl, Target = target, Root = root, baseText = baseText, color = color}
end

task.spawn(function()
    while true do
        task.wait(0.6)
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local myPos = hrp and hrp.Position or Vector3.zero
        for tag, items in pairs(espTrackers) do
            for obj, e in pairs(items) do
                if not e.Target or not e.Target.Parent or not e.Root or not e.Root.Parent then
                    removeESPSingle(tag, obj)
                elseif hrp and e.Label then
                    local dist = math.floor((e.Root.Position - myPos).Magnitude)
                    e.Label.Text = e.baseText .. "\n[" .. dist .. " studs]"
                end
            end
        end
    end
end)

local function scanGhostESP()
    if not espEnabled.Ghost then
        return
    end
    local c = Workspace:FindFirstChild("Ghost")
    local found = false
    if c and c:IsA("Model") then
        local r = c.PrimaryPart or c:FindFirstChild("HumanoidRootPart") or c:FindFirstChildWhichIsA("BasePart")
        if r then
            local hunting = c:FindFirstChild("Hunting") and c.Hunting.Value == true
            addESP("Ghost", c, r, hunting and "GHOST (HUNTING!)" or "GHOST",
                hunting and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(255, 75, 75))
            found = true
        end
    end
    if not found then
        for _, ch in ipairs(Workspace:GetChildren()) do
            if ch:IsA("Model") and ch ~= LocalPlayer.Character and not Players:GetPlayerFromCharacter(ch) then
                if ch.Name ~= "SLS_GHOST" and ch.Name ~= "ShadowyFigure" then
                    local isGhost = ch:FindFirstChild("Hunting") or ch:FindFirstChild("OriginalGhostName")
                        or ch:GetAttribute("Ghost") or ch.Name:lower():find("ghost")
                    if isGhost then
                        local r = ch.PrimaryPart or ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChildWhichIsA("BasePart")
                        if r then
                            local hunting = ch:FindFirstChild("Hunting") and ch.Hunting.Value == true
                            addESP("Ghost", ch, r, hunting and "GHOST (HUNTING!)" or "GHOST",
                                hunting and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(255, 75, 75))
                            break
                        end
                    end
                end
            end
        end
    end
end

local currentRoomZone = nil

local function scanGhostRoomESP()
    if not espEnabled.GhostRoom then
        if currentRoomZone then
            removeESPSingle("GhostRoom", currentRoomZone)
            currentRoomZone = nil
        end
        return
    end
    local map = Workspace:FindFirstChild("Map")
    local zones = map and map:FindFirstChild("Zones")
    if not zones then
        return
    end
    local coldest, coldestTemp = nil, 999
    for _, z in ipairs(zones:GetChildren()) do
        local zn = z.Name:lower()
        local skip = z:FindFirstChild("Exclude") or zn:find("hitbox")
            or zn:find("zonelist") or zn == "zones"
        if not skip then
            local tv = z:FindFirstChild("_____Temperature")
            if tv and tv:IsA("NumberValue") and typeof(tv.Value) == "number" and tv.Value < coldestTemp then
                coldestTemp = tv.Value
                coldest = z
            end
        end
    end
    if not coldest then
        if currentRoomZone then
            removeESPSingle("GhostRoom", currentRoomZone)
            currentRoomZone = nil
        end
        return
    end
    if currentRoomZone and currentRoomZone ~= coldest then
        removeESPSingle("GhostRoom", currentRoomZone)
        currentRoomZone = nil
    end
    if currentRoomZone and not currentRoomZone.Parent then
        currentRoomZone = nil
    end
    local p = coldest:IsA("BasePart") and coldest or coldest:FindFirstChildWhichIsA("BasePart", true)
    if p then
        local isFreezing = isFreezingValue(coldestTemp)
        local color = isFreezing and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(100, 180, 255)
        local tag = isFreezing and "FREEZING" or "COLDEST"
        addESP("GhostRoom", coldest, p, tag .. " " .. coldest.Name .. " (" .. string.format("%.2f", coldestTemp) .. ")", color)
        currentRoomZone = coldest
    end
end

local function scanBreakerESP()
    if not espEnabled.Breaker then
        return
    end
    local map = Workspace:FindFirstChild("Map")
    local gf = map and map:FindFirstChild("Generators")
    if gf then
        for _, g in ipairs(gf:GetChildren()) do
            local p = g:IsA("BasePart") and g or g:FindFirstChildWhichIsA("BasePart", true)
            if p then
                addESP("Breaker", g, p, "BREAKER: " .. g.Name, Color3.fromRGB(255, 220, 50))
            end
        end
    end
end

local function isBooBooName(name)
    local n = (name or ""):lower()
    return n:find("booboo") or n:find("boo-boo") or n:find("boo_boo")
end

local CURSED_KW = {
    "music box", "musicbox", "music_box", "tarot", "tarotcard", "tarot_card", "tarot cards";
    "ouija", "ouijaboard", "ouija board", "spirit board", "spiritboard";
    "summoning circle", "summoningcircle", "summoning";
    "monkey paw", "monkeypaw";
    "haunted mirror", "hauntedmirror";
    "cursed", "cursedpossession", "curseditem", "cursedobject";
    "voodoo";
    "brokenmusic", "broken_music", "broken music";
}

local function hasCursedKeyword(name)
    local n = (name or ""):lower()
    for _, kw in ipairs(CURSED_KW) do
        if n:find(kw, 1, true) then
            return true
        end
    end
    return false
end

local cursedScanned = setmetatable({}, {__mode = "k"})

local function scanCursedESP()
    if not espEnabled.Cursed then
        return
    end
    for obj in pairs(espTrackers.Cursed) do
        if not obj.Parent then
            removeESPSingle("Cursed", obj)
        end
    end
    local map = Workspace:FindFirstChild("Map")
    local function tryMark(item)
        if not item or not item.Parent or espTrackers.Cursed[item] or cursedScanned[item] then
            return
        end
        if isBooBooName(item.Name) then
            return
        end
        if Players:GetPlayerFromCharacter(item) then
            return
        end
        if item:IsA("Tool") and item.Parent and item.Parent:FindFirstChildOfClass("Humanoid") then
            return
        end
        if not hasCursedKeyword(item.Name) then
            return
        end
        local p = item:IsA("BasePart") and item or item:FindFirstChild("Handle") or item:FindFirstChildWhichIsA("BasePart", true)
        if not p then
            return
        end
        if p.Transparency >= 1 and (not item:IsA("Model") or #item:GetChildren() == 0) then
            return
        end
        addESP("Cursed", item, p, "CURSED: " .. item.Name, Color3.fromRGB(220, 80, 255))
        cursedScanned[item] = true
    end
    local folders = {"CursedSpawns", "CursedPossessions", "CursedItems", "CursedObjects", "Cursed", "Possessions", "Cursed_Objects", "Cursed_Possessions"}
    for _, folderName in ipairs(folders) do
        if map then
            local f = map:FindFirstChild(folderName)
            if f then
                for _, item in ipairs(f:GetChildren()) do
                    tryMark(item)
                end
            end
        end
        local f2 = Workspace:FindFirstChild(folderName)
        if f2 then
            for _, item in ipairs(f2:GetChildren()) do
                tryMark(item)
            end
        end
    end
    if map then
        local items = map:FindFirstChild("Items")
        if items then
            for _, item in ipairs(items:GetChildren()) do
                tryMark(item)
            end
        end
        for _, item in ipairs(map:GetChildren()) do
            tryMark(item)
        end
    end
    for _, item in ipairs(Workspace:GetChildren()) do
        tryMark(item)
    end
end

local boobooScanned = setmetatable({}, {__mode = "k"})

local function scanBooBooESP()
    if not espEnabled.BooBoo then
        return
    end
    for obj in pairs(espTrackers.BooBoo) do
        if not obj.Parent then
            removeESPSingle("BooBoo", obj)
        end
    end
    local function tryMark(item)
        if not item or not item.Parent or espTrackers.BooBoo[item] or boobooScanned[item] then
            return
        end
        if Players:GetPlayerFromCharacter(item) then
            return
        end
        if item:IsA("Tool") and item.Parent and item.Parent:FindFirstChildOfClass("Humanoid") then
            return
        end
        if not isBooBooName(item.Name) then
            return
        end
        local p = item:IsA("BasePart") and item or item:FindFirstChild("Handle") or item:FindFirstChildWhichIsA("BasePart", true)
        if not p or p.Transparency >= 1 then
            return
        end
        addESP("BooBoo", item, p, "Boo-Boo Doll", Color3.fromRGB(255, 100, 220))
        boobooScanned[item] = true
    end
    for _, item in ipairs(Workspace:GetChildren()) do
        tryMark(item)
    end
    local map = Workspace:FindFirstChild("Map")
    if map then
        for _, item in ipairs(map:GetChildren()) do
            tryMark(item)
        end
    end
end

local teammateHooked = setmetatable({}, {__mode = "k"})

local function killTeammateESP(char)
    if char then
        removeESPSingle("Teammates", char)
    end
end

local function isPlayerDead(plr, char, hum)
    if not char or not char.Parent or char.Parent ~= Workspace then
        return true
    end
    if not hum or hum.Health <= 0 then
        return true
    end
    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Dead then
        return true
    end
    if st == Enum.HumanoidStateType.Physics and hum.Health <= 0 then
        return true
    end
    if hum.PlatformStand and hum.Health <= 0 then
        return true
    end
    if plr and plr.Character ~= char then
        return true
    end
    return false
end

local function attachTeammateDeathHook(plr, char)
    if teammateHooked[char] then
        return
    end
    teammateHooked[char] = true
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            killTeammateESP(char)
        end)
        hum:GetPropertyChangedSignal("Health"):Connect(function()
            if hum.Health <= 0 then
                killTeammateESP(char)
            end
        end)
        hum.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.Dead then
                killTeammateESP(char)
            elseif newState == Enum.HumanoidStateType.Physics and hum.Health <= 0 then
                killTeammateESP(char)
            end
        end)
    end
    char.AncestryChanged:Connect(function(_, newParent)
        if newParent == nil or newParent ~= Workspace then
            killTeammateESP(char)
        end
    end)
    pcall(function()
        plr.CharacterRemoving:Connect(function(c)
            if c == char then
                killTeammateESP(char)
            end
        end)
    end)
end

local function scanTeammatesESP()
    if not espEnabled.Teammates then
        for obj in pairs(espTrackers.Teammates) do
            removeESPSingle("Teammates", obj)
        end
        return
    end
    for obj in pairs(espTrackers.Teammates) do
        if not obj.Parent or obj.Parent ~= Workspace then
            killTeammateESP(obj)
        else
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local owner = Players:GetPlayerFromCharacter(obj)
            if isPlayerDead(owner, obj, hum) then
                killTeammateESP(obj)
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char and char.Parent == Workspace and not espTrackers.Teammates[char] then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hum and hrp and not isPlayerDead(plr, char, hum) then
                    addESP("Teammates", char, hrp, plr.DisplayName, Color3.fromRGB(60, 255, 120))
                    attachTeammateDeathHook(plr, char)
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if espEnabled.Ghost then
            pcall(scanGhostESP)
        end
        if espEnabled.GhostRoom then
            pcall(scanGhostRoomESP)
        end
        if espEnabled.Breaker then
            pcall(scanBreakerESP)
        end
        if espEnabled.Cursed then
            pcall(scanCursedESP)
        end
        if espEnabled.BooBoo then
            pcall(scanBooBooESP)
        end
        if espEnabled.Teammates then
            pcall(scanTeammatesESP)
        end
    end
end)

local fullBrightEnabled = false
local origLight = {
    Brightness = Lighting.Brightness;
    ClockTime = Lighting.ClockTime;
    FogEnd = Lighting.FogEnd;
    GlobalShadows = Lighting.GlobalShadows;
    Ambient = Lighting.Ambient;
    OutdoorAmbient = Lighting.OutdoorAmbient;
}
local applyingFB = false
local LightingConn = nil

local function setFullBright(s)
    fullBrightEnabled = s
    applyingFB = true
    if s then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(220, 220, 220)
        Lighting.OutdoorAmbient = Color3.fromRGB(220, 220, 220)
        if not LightingConn then
            local queued = false
            LightingConn = Lighting.Changed:Connect(function()
                if applyingFB or queued then
                    return
                end
                queued = true
                task.spawn(function()
                    queued = false
                    if fullBrightEnabled then
                        setFullBright(true)
                    end
                end)
            end)
        end
    else
        if LightingConn then
            LightingConn:Disconnect()
            LightingConn = nil
        end
        Lighting.Brightness = origLight.Brightness
        Lighting.ClockTime = origLight.ClockTime
        Lighting.FogEnd = origLight.FogEnd
        Lighting.GlobalShadows = origLight.GlobalShadows
        Lighting.Ambient = origLight.Ambient
        Lighting.OutdoorAmbient = origLight.OutdoorAmbient
    end
    applyingFB = false
end

local TabAutomation = Window:Tab({Title = "Automation", Icon = "play"})
local TabESP = Window:Tab({Title = "ESP & Vision", Icon = "eye"})
local TabMovement = Window:Tab({Title = "Movement", Icon = "wrench"})

local SecAuto = TabAutomation:Section({Title = "Auto Evidence Hunter", Opened = true})
autoStatusParagraph = SecAuto:Paragraph({Title = "Status Deteksi Bukti", Content = updateAutoStatusText()})

SecAuto:Toggle({
    Title = "Auto Scan & Detect Evidences";
    Description = "Tracking: EMF, Freezing, Writing, Spirit Box, UV, Orb, SLS";
    Value = false;
    Callback = function(s)
        autoEvidenceDetectActive = s
        if s then
            pcall(updateGhostRoomTemp)
            safeNotify({Title = "Evidence Hunter", Content = "Auto Detect ON", Duration = 3})
        else
            safeNotify({Title = "Evidence Hunter", Content = "Auto Detect OFF", Duration = 2})
        end
        refreshAutoStatusUI(true)
    end;
})

TabAutomation:Section({Title = "Ghost Hunt Alert", Opened = true}):Toggle({
    Title = "Hunt Notification";
    Description = "Notifikasi saat ghost mulai berburu";
    Value = true;
    Callback = function(s)
        huntNotifyEnabled = s
    end;
})

TabAutomation:Section({Title = "Instant Interact", Opened = true}):Toggle({
    Title = "Instant Interact";
    Description = "ProximityPrompt jadi 1-tap";
    Value = false;
    Callback = function(s)
        instantInteractEnabled = s
        if s then
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("ProximityPrompt") then
                    pcall(applyInstantInteract, v)
                end
            end
            enablePromptWatcher()
        else
            disablePromptWatcher()
            restoreInstantInteract()
        end
    end;
})

TabAutomation:Section({Title = "Utility", Opened = false}):Button({
    Title = "Reset Bukti";
    Callback = function()
        detectedEvidences = {}
        uvEvidenceFired = false
        ghostOrbEvidenceFired = false
        refreshAutoStatusUI(true)
        safeNotify({Title = "Reset", Content = "Data bukti dibersihkan.", Duration = 2})
    end;
})

local SecESP = TabESP:Section({Title = "Visual ESP", Opened = true})
SecESP:Toggle({Title = "Ghost ESP", Value = false, Callback = function(s)
    espEnabled.Ghost = s
    if not s then
        clearESP("Ghost")
    else
        scanGhostESP()
    end
end})
SecESP:Toggle({Title = "Ghost Room ESP (Auto-Switch)", Value = false, Callback = function(s)
    espEnabled.GhostRoom = s
    if not s then
        if currentRoomZone then
            removeESPSingle("GhostRoom", currentRoomZone)
        end
        currentRoomZone = nil
    end
end})
SecESP:Toggle({Title = "Breaker ESP", Value = false, Callback = function(s)
    espEnabled.Breaker = s
    if not s then
        clearESP("Breaker")
    else
        scanBreakerESP()
    end
end})
SecESP:Toggle({Title = "Cursed Object ESP", Value = false, Callback = function(s)
    espEnabled.Cursed = s
    if not s then
        clearESP("Cursed")
    else
        scanCursedESP()
    end
end})
SecESP:Toggle({Title = "Boo-Boo Doll ESP", Value = false, Callback = function(s)
    espEnabled.BooBoo = s
    if not s then
        clearESP("BooBoo")
    else
        scanBooBooESP()
    end
end})
SecESP:Toggle({Title = "Teammates ESP (Hidup saja)", Value = false, Callback = function(s)
    espEnabled.Teammates = s
    if not s then
        clearESP("Teammates")
    else
        scanTeammatesESP()
    end
end})

TabESP:Section({Title = "Vision", Opened = true}):Toggle({
    Title = "FullBright & No Fog";
    Value = false;
    Callback = function(s)
        setFullBright(s)
    end;
})

local SecMove = TabMovement:Section({Title = "Movement", Opened = true})
SecMove:Toggle({
    Title = "Infinite Stamina + Sprint Boost";
    Value = false;
    Callback = function(s)
        infiniteStaminaEnabled = s
        if s then
            pcall(scanStaminaAll)
            pcall(forceStamina)
        end
    end;
})
SecMove:Toggle({
    Title = "Infinite NoClip";
    Value = false;
    Callback = function(s)
        infiniteNoclipEnabled = s
        if s then
            enableNoclip()
        else
            disableNoclip()
        end
    end;
})

SecMove:Toggle({
    Title = "Enable Custom WalkSpeed";
    Value = false;
    Callback = function(s)
        customWalkSpeedEnabled = s
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if s then
            if hum then
                hum.WalkSpeed = targetWalkSpeed
            end
        else
            targetWalkSpeed = DEFAULT_WALKSPEED
            if walkSpeedSlider then
                pcall(function() walkSpeedSlider:Set(DEFAULT_WALKSPEED) end)
                pcall(function() walkSpeedSlider:SetValue(DEFAULT_WALKSPEED) end)
                pcall(function() walkSpeedSlider.Value = DEFAULT_WALKSPEED end)
            end
            if hum then
                hum.WalkSpeed = originalWalkSpeed or 16
            end
        end
    end;
})

walkSpeedSlider = SecMove:Slider({
    Title = "WalkSpeed Value";
    Description = "16-120";
    Value = {
        Min = 16;
        Max = 120;
        Default = 20;
    };
    Callback = function(v)
        if typeof(v) == "table" then
            v = v.Value or v.Value1 or tonumber(v) or v
        end
        v = tonumber(v)
        if not v then
            return
        end
        targetWalkSpeed = v
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if customWalkSpeedEnabled and hum then
            hum.WalkSpeed = v
        end
    end;
})

local SecTP = TabMovement:Section({Title = "Quick Teleports", Opened = true})
SecTP:Button({Title = "Teleport to Van", Callback = function()
    local cf = findVanCFrame()
    if cf and teleportTo(cf) then
        safeNotify({Title = "Teleport", Content = "Ke Van", Duration = 2})
    else
        safeNotify({Title = "Teleport", Content = "Van tidak ditemukan", Duration = 3})
    end
end})
SecTP:Button({Title = "Teleport to Ghost Room", Callback = function()
    if ghostRoomName then
        local map = Workspace:FindFirstChild("Map")
        local zones = map and map:FindFirstChild("Zones")
        local z = zones and zones:FindFirstChild(ghostRoomName)
        if z then
            local p = z:IsA("BasePart") and z or z:FindFirstChildWhichIsA("BasePart", true)
            if p and teleportTo(p.CFrame + Vector3.new(0, 1.5, 0)) then
                safeNotify({Title = "Teleport", Content = "Ke " .. ghostRoomName, Duration = 2})
                return
            end
        end
    end
    safeNotify({Title = "Teleport", Content = "Ghost Room tidak ditemukan", Duration = 3})
end})
SecTP:Button({Title = "Teleport to Breaker", Callback = function()
    local cf = findGeneratorCFrame()
    if cf and teleportTo(cf) then
        safeNotify({Title = "Teleport", Content = "Ke Breaker", Duration = 2})
    else
        safeNotify({Title = "Teleport", Content = "Breaker tidak ditemukan", Duration = 3})
    end
end})

local lastMap = ""
task.spawn(function()
    while true do
        local mn = ReplicatedStorage:FindFirstChild("ReplicatedValues")
        mn = mn and mn:FindFirstChild("MapName")
        local cur = mn and mn.Value or ""
        if cur ~= "" and cur ~= lastMap then
            lastMap = cur
            detectedEvidences = {}
            uvEvidenceFired = false
            ghostOrbEvidenceFired = false
            ghostRoomTemp = nil
            ghostRoomName = nil
            hookedTools = setmetatable({}, {__mode = "k"})
            hookedRemotes = setmetatable({}, {__mode = "k"})
            hookedValueObjects = setmetatable({}, {__mode = "k"})
            cursedScanned = setmetatable({}, {__mode = "k"})
            boobooScanned = setmetatable({}, {__mode = "k"})
            teammateHooked = setmetatable({}, {__mode = "k"})
            hookedSpiritSounds = setmetatable({}, {__mode = "k"})
            hookedButtons = setmetatable({}, {__mode = "k"})
            debugCounts = setmetatable({}, {__mode = "k"})
            lastSpiritBoxEquippedTime = 0
            if currentRoomZone then
                removeESPSingle("GhostRoom", currentRoomZone)
                currentRoomZone = nil
            end
            StaminaNumberValues, StaminaAttrTargets = {}, {}
            LastStaminaScan = 0
            lastHuntNotify = 0
            statusUpdateFailures = 0
            for tag in pairs(espTrackers) do
                clearESP(tag)
            end
            refreshAutoStatusUI(true)
        end
        task.wait(3)
    end
end)

refreshAutoStatusUI(true)
safeNotify({Title = "SysHub v6.9.37", Content = "Blair Assistant siap!", Duration = 5})
print("[SysHub v6.9.37] Loaded")