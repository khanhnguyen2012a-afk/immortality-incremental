-- ONYX HUB - FULL + GUI CONTROL
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RS = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Onyx Hub",
    LoadingTitle = "Loading Onyx Hub",
    LoadingSubtitle = "by Onyx",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- ===== CHECK STATUS =====
local status = {
    speedRemote = false, folder = false, teleportPart = false,
    starCount = 0, charReady = false,
    remotePath = "?", folderPath = "?", teleportPath = "?",
}

local function checkRemote()
    local ev = RS:FindFirstChild("RemoteEvents")
    if ev then
        local r = ev:FindFirstChild("GainMiasma")
        if r then
            status.speedRemote = true
            status.remotePath = r:GetFullName()
            return r
        end
    end
    status.speedRemote = false
    return nil
end

local function checkFolder()
    local f = workspace:FindFirstChild("StarForgingLocalVisuals")
    if f then
        status.folder = true
        status.folderPath = f:GetFullName()
        return f
    end
    status.folder = false
    return nil
end

local function checkTeleportPart()
    local cur = workspace
    for _, name in ipairs({"StarForgingFoundation", "TopPart"}) do
        if not cur then return nil end
        cur = cur:FindFirstChild(name)
    end
    if cur then
        status.teleportPart = true
        status.teleportPath = cur:GetFullName()
        return cur
    end
    status.teleportPart = false
    return nil
end

local function checkChar()
    local char = LP.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
        status.charReady = true
        return true
    end
    status.charReady = false
    return false
end

local miasmaRemote = checkRemote()
local folder = checkFolder()
local teleportPart = checkTeleportPart()
checkChar()

local function countStars()
    if not folder then return 0 end
    local n = 0
    for _, v in ipairs(folder:GetChildren()) do
        if v.Name:match("^Star_%d+") then n = n + 1 end
    end
    return n
end

status.starCount = countStars()

-- ===== ANTI-AFK MODULE =====
local AntiAFK = {}
AntiAFK.enabled = false
AntiAFK.thread = nil
AntiAFK.idleConn = nil
AntiAFK.interval = 60
AntiAFK.restartToken = 0

function AntiAFK.start()
    if AntiAFK.enabled then return end
    AntiAFK.enabled = true

    AntiAFK.idleConn = LP.Idled:Connect(function()
        if not AntiAFK.enabled then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)

    AntiAFK.restartToken += 1
    local myToken = AntiAFK.restartToken
    AntiAFK.thread = task.spawn(function()
        while AntiAFK.enabled and myToken == AntiAFK.restartToken do
            task.wait(AntiAFK.interval)
            if not AntiAFK.enabled then break end
            if myToken ~= AntiAFK.restartToken then break end
            local char = LP.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end
        end
    end)
end

function AntiAFK.stop()
    AntiAFK.enabled = false
    AntiAFK.restartToken += 1
    if AntiAFK.thread then
        pcall(task.cancel, AntiAFK.thread)
        AntiAFK.thread = nil
    end
    if AntiAFK.idleConn then
        AntiAFK.idleConn:Disconnect()
        AntiAFK.idleConn = nil
    end
end

function AntiAFK.setInterval(sec)
    AntiAFK.interval = sec
    if AntiAFK.enabled then
        AntiAFK.stop()
        task.wait(0.1)
        AntiAFK.start()
    end
end

-- ===== CONFIG =====
local DEFAULT_SPEED = 16
local currentSpeed = 100
local speedEnabled = false
local humanoid = nil

local function bindChar(char)
    humanoid = char:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.WalkSpeed = speedEnabled and currentSpeed or DEFAULT_SPEED
    end
end
if LP.Character then bindChar(LP.Character) end
LP.CharacterAdded:Connect(bindChar)

-- MIASMA
local spamEnabled = false
local spamDelay = 0.1

-- STARS
local walkRunning = false
local walkSpeed = 25
local maxWalkTime = 6
local FOLDER_NAME = "StarForgingLocalVisuals"

local starCache = {}
local cacheTime = 0
local CACHE_TTL = 0.3

local function refreshCache()
    starCache = {}
    if not folder or not folder.Parent then
        folder = workspace:FindFirstChild(FOLDER_NAME)
    end
    if not folder then return end
    for _, v in ipairs(folder:GetChildren()) do
        if v.Name:match("^Star_%d+") and v.Parent then
            local part = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
            if part then
                starCache[#starCache + 1] = { star = v, pos = part.Position }
            end
        end
    end
    cacheTime = tick()
end

local function getCache()
    if tick() - cacheTime > CACHE_TTL then refreshCache() end
    return starCache
end

local function pickRandom()
    local cache = getCache()
    local valid = {}
    for _, entry in ipairs(cache) do
        if entry.star.Parent then valid[#valid + 1] = entry end
    end
    if #valid == 0 then return nil, nil end
    local picked = valid[math.random(1, #valid)]
    return picked.star, picked.pos
end

local function teleportToStart()
    if not teleportPart or not teleportPart.Parent then
        teleportPart = checkTeleportPart()
    end
    if not teleportPart then return false end
    local char = LP.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.CFrame = CFrame.new(teleportPart.Position + Vector3.new(0, teleportPart.Size.Y/2 + 3, 0))
    return true
end

local function resetWalkSpeed()
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = speedEnabled and currentSpeed or DEFAULT_SPEED
        end
    end
end

local function startWalk()
    if walkRunning then return end
    teleportToStart()
    task.wait(0.3)

    walkRunning = true
    task.spawn(function()
        while walkRunning do
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not (hrp and hum) then
                task.wait(0.3)
                continue
            end
            hum.WalkSpeed = walkSpeed

            local star, targetPos = pickRandom()
            if not star or not targetPos then
                task.wait(0.1)
                continue
            end

            hum:MoveTo(targetPos)

            local startTime = tick()
            while tick() - startTime < maxWalkTime do
                if not walkRunning then break end
                if not star.Parent then break end
                if (hrp.Position - targetPos).Magnitude < 4 then break end
                task.wait(0.1)
            end
        end
    end)
end

local function stopWalk()
    walkRunning = false
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.RootPart then
            hum:MoveTo(hum.RootPart.Position)
        end
    end
    resetWalkSpeed()
end

-- ===== GUI CONTROL HELPERS =====
local function getSpiritGui()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("MainGui")
    if not main then return nil end
    return main:FindFirstChild("SpiritRootsGui")
end

local function getBloodlinesGui()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("MainGui")
    if not main then return nil end
    return main:FindFirstChild("BloodlinesGui")
end

local function setGuiState(gui, state)
    if not gui then return false end
    local ok = pcall(function()
        if gui:IsA("ScreenGui") then
            gui.Enabled = state
        elseif gui:IsA("GuiObject") then
            gui.Visible = state
        end
    end)
    return ok
end

-- ===== TABS =====
local StarsTab = Window:CreateTab("Stars", 4483362458)
local MiasmaTab = Window:CreateTab("Miasma", 4483362458)
local SpeedTab = Window:CreateTab("Speed", 4483362458)
local GUITab = Window:CreateTab("GUI Control", 4483362458)
local AntiAFKTab = Window:CreateTab("Anti-AFK", 4483362458)
local StatusTab = Window:CreateTab("Status", 4483362458)

-- ============ STARS TAB ============
StarsTab:CreateSection("Auto Collect Star (Random)")

StarsTab:CreateToggle({
    Name = "Bật Auto Walk (random star)",
    CurrentValue = false,
    Flag = "WalkToggle",
    Callback = function(v)
        if v then startWalk() else stopWalk() end
    end,
})

StarsTab:CreateSection("Tuning")

StarsTab:CreateSlider({
    Name = "Walk Speed (đi bộ)",
    Range = {16, 100}, Increment = 1, Suffix = "s/s",
    CurrentValue = 25, Flag = "WalkSpeedSlider",
    Callback = function(v)
        walkSpeed = v
        if walkRunning then
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = v end
        end
    end,
})

-- ============ MIASMA TAB ============
MiasmaTab:CreateSection("Auto Spam GainMiasma")

MiasmaTab:CreateToggle({
    Name = "Bật Auto Spam",
    CurrentValue = false,
    Flag = "SpamToggle",
    Callback = function(v)
        spamEnabled = v
    end,
})

MiasmaTab:CreateButton({
    Name = "Fire 1 Lần",
    Callback = function()
        if miasmaRemote then
            pcall(function() miasmaRemote:FireServer() end)
        end
    end,
})

-- ============ SPEED TAB ============
SpeedTab:CreateSection("Speed Control")

SpeedTab:CreateToggle({
    Name = "Bật Speed",
    CurrentValue = false,
    Flag = "SpeedToggle",
    Callback = function(v)
        speedEnabled = v
        if not walkRunning and humanoid then
            humanoid.WalkSpeed = speedEnabled and currentSpeed or DEFAULT_SPEED
        end
    end,
})

SpeedTab:CreateSlider({
    Name = "Speed Value",
    Range = {16, 500}, Increment = 1, Suffix = "studs",
    CurrentValue = 100, Flag = "SpeedSlider",
    Callback = function(v)
        currentSpeed = v
        if speedEnabled and not walkRunning and humanoid then
            humanoid.WalkSpeed = v
        end
    end,
})

SpeedTab:CreateButton({
    Name = "Reset về 100",
    Callback = function()
        currentSpeed = 100
        if speedEnabled and not walkRunning and humanoid then
            humanoid.WalkSpeed = 100
        end
    end,
})

-- ============ GUI CONTROL TAB ============
GUITab:CreateSection("Toggle GUI")

GUITab:CreateToggle({
    Name = "SpiritRootsGui",
    CurrentValue = false,
    Flag = "SpiritGuiToggle",
    Callback = function(v)
        local gui = getSpiritGui()
        if gui then setGuiState(gui, v) end
    end,
})

GUITab:CreateToggle({
    Name = "BloodlinesGui",
    CurrentValue = false,
    Flag = "BloodlinesGuiToggle",
    Callback = function(v)
        local gui = getBloodlinesGui()
        if gui then setGuiState(gui, v) end
    end,
})

GUITab:CreateSection("Status")

local spiritStat = GUITab:CreateParagraph({ 
    Title = "SpiritRootsGui", 
    Content = "..." 
})
local bloodStat = GUITab:CreateParagraph({ 
    Title = "BloodlinesGui", 
    Content = "..." 
})

-- Live update GUI status
task.spawn(function()
    while task.wait(1) do
        local sg = getSpiritGui()
        if sg then
            local state = sg:IsA("ScreenGui") and sg.Enabled or sg.Visible
            spiritStat:Set({
                Title = "SpiritRootsGui",
                Content = string.format("✓ Found | State: %s", tostring(state))
            })
        else
            spiritStat:Set({
                Title = "SpiritRootsGui",
                Content = "✗ Không tìm thấy"
            })
        end

        local bg = getBloodlinesGui()
        if bg then
            local state = bg:IsA("ScreenGui") and bg.Enabled or bg.Visible
            bloodStat:Set({
                Title = "BloodlinesGui",
                Content = string.format("✓ Found | State: %s", tostring(state))
            })
        else
            bloodStat:Set({
                Title = "BloodlinesGui",
                Content = "✗ Không tìm thấy"
            })
        end
    end
end)

-- ============ ANTI-AFK TAB ============
AntiAFKTab:CreateSection("Anti AFK")

AntiAFKTab:CreateToggle({
    Name = "Bật Anti-AFK",
    CurrentValue = false,
    Flag = "AntiAFKToggle",
    Callback = function(v)
        if v then AntiAFK.start() else AntiAFK.stop() end
    end,
})

AntiAFKTab:CreateSlider({
    Name = "Interval nhảy",
    Range = {10, 300}, Increment = 5, Suffix = "s",
    CurrentValue = 60, Flag = "AntiAFKInterval",
    Callback = function(v)
        AntiAFK.setInterval(v)
    end,
})

AntiAFKTab:CreateParagraph({
    Title = "Info",
    Content = "Idle event + nhảy theo interval. Slider 10-300s."
})

-- ============ STATUS TAB ============
StatusTab:CreateSection("System Status")

local remoteStat = StatusTab:CreateParagraph({ Title = "GainMiasma Remote", Content = "..." })
local folderStat = StatusTab:CreateParagraph({ Title = "Star Folder", Content = "..." })
local tpStat = StatusTab:CreateParagraph({ Title = "Teleport Part", Content = "..." })
local charStat = StatusTab:CreateParagraph({ Title = "Character", Content = "..." })
local activeStat = StatusTab:CreateParagraph({ Title = "Active Features", Content = "..." })
local starStat = StatusTab:CreateParagraph({ Title = "Live Star Count", Content = "0" })

task.spawn(function()
    while task.wait(1) do
        if not miasmaRemote or not miasmaRemote.Parent then
            miasmaRemote = checkRemote()
        end
        remoteStat:Set({
            Title = "GainMiasma Remote",
            Content = status.speedRemote and ("✓ " .. status.remotePath) or "✗ Không tìm thấy",
        })

        if not folder or not folder.Parent then
            folder = checkFolder()
        end
        local starCount = countStars()
        status.starCount = starCount
        folderStat:Set({
            Title = "Star Folder",
            Content = status.folder and ("✓ " .. status.folderPath) or "✗ Không tìm thấy",
        })

        if not teleportPart or not teleportPart.Parent then
            teleportPart = checkTeleportPart()
        end
        tpStat:Set({
            Title = "Teleport Part",
            Content = status.teleportPart and ("✓ " .. status.teleportPath) or "✗ Không tìm thấy",
        })

        checkChar()
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        charStat:Set({
            Title = "Character",
            Content = status.charReady
                and string.format("✓ Ready | HP: %d | Speed: %d", hum.Health, hum.WalkSpeed)
                or "✗ Chưa spawn",
        })

        activeStat:Set({
            Title = "Active Features",
            Content = string.format(
                "Speed: %s\nMiasma: %s\nStars: %s\nAnti-AFK: %s",
                speedEnabled and "ON" or "OFF",
                spamEnabled and "ON" or "OFF",
                walkRunning and "ON" or "OFF",
                AntiAFK.enabled and "ON" or "OFF"
            ),
        })

        starStat:Set({
            Title = "Live Star Count",
            Content = tostring(starCount) .. " stars",
        })
    end
end)

-- ===== MIASMA SPAM LOOP =====
task.spawn(function()
    while true do
        if spamEnabled and miasmaRemote then
            pcall(function() miasmaRemote:FireServer() end)
            task.wait(spamDelay)
        else
            task.wait(0.1)
        end
    end
end)

-- ===== WELCOME =====
Rayfield:Notify({
    Title = "Onyx Hub",
    Content = string.format(
        "Remote: %s | Folder: %s | Part: %s",
        status.speedRemote and "OK" or "MISS",
        status.folder and "OK" or "MISS",
        status.teleportPart and "OK" or "MISS"
    ),
    Duration = 4,
})
