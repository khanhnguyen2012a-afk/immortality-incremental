-- ONYX HUB - FULL + BEAST
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

-- BEAST
local beastRemote = nil
local soulFocusRemote = nil
do
    local ev = RS:FindFirstChild("RemoteEvents")
    if ev then
        beastRemote = ev:FindFirstChild("SetBeastStage")
        soulFocusRemote = ev:FindFirstChild("SetSoulFocus")
    end
end

local pendingStage = 0
local lastHighestStage = 0
local autoRunning = false

local function getHighestStage()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local display = pg:FindFirstChild("BeastStageDisplay")
    if not display then return nil end
    local root = display:FindFirstChild("Root")
    if not root then return nil end
    local textLabel = root:FindFirstChild("HighestStageText")
    if not textLabel then return nil end
    local text = textLabel.Text
    return tonumber(text:match("%d+"))
end

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
local function findGui(name)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local direct = pg:FindFirstChild(name)
    if direct then return direct end
    local main = pg:FindFirstChild("MainGui")
    if main then return main:FindFirstChild(name) end
    return nil
end

local function forceShow(gui, state)
    if not gui then return end
    pcall(function()
        if gui:IsA("ScreenGui") then
            gui.Enabled = state
            if state then
                gui.DisplayOrder = 999
                gui.IgnoreGuiInset = true
            end
        elseif gui:IsA("GuiObject") then
            gui.Visible = state
        end

        if state then
            for _, c in ipairs(gui:GetDescendants()) do
                if c:IsA("GuiObject") then
                    pcall(function()
                        c.Visible = true
                        c.ZIndex = math.max(c.ZIndex, 50)
                    end)
                end
                if c:IsA("CanvasGroup") then
                    pcall(function()
                        c.GroupTransparency = 0
                    end)
                end
            end
        end
    end)
end

-- ===== TABS =====
local StarsTab = Window:CreateTab("Stars", 4483362458)
local MiasmaTab = Window:CreateTab("Miasma", 4483362458)
local BeastTab = Window:CreateTab("Beast", 4483362458)
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

-- ============ BEAST TAB ============
BeastTab:CreateSection("Set Beast Stage")

BeastTab:CreateInput({
    Name = "Stage Number",
    PlaceholderText = "Nhập số stage",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local num = tonumber(text)
        if num then
            pendingStage = num
        else
            pendingStage = 0
        end
    end,
})

BeastTab:CreateButton({
    Name = "Set Stage",
    Callback = function()
        if pendingStage > 0 and beastRemote then
            pcall(function()
                beastRemote:FireServer(pendingStage)
            end)
            Rayfield:Notify({
                Title = "Beast",
                Content = "Đã set stage " .. pendingStage,
                Duration = 2,
            })
        else
            Rayfield:Notify({
                Title = "Lỗi",
                Content = "Nhập số stage trước",
                Duration = 2,
            })
        end
    end,
})

BeastTab:CreateSection("Auto Leo Stage")

BeastTab:CreateToggle({
    Name = "Bật Auto Leo Stage",
    CurrentValue = false,
    Flag = "AutoStageToggle",
    Callback = function(v)
        autoRunning = v
        if v then
            if soulFocusRemote then
                pcall(function()
                    soulFocusRemote:FireServer("Qi")
                end)
            end
            lastHighestStage = 0
        end
    end,
})

BeastTab:CreateSection("Status")

local beastStat = BeastTab:CreateParagraph({ Title = "SetBeastStage", Content = "..." })
local soulStat = BeastTab:CreateParagraph({ Title = "SetSoulFocus", Content = "..." })
local highStat = BeastTab:CreateParagraph({ Title = "Highest Stage", Content = "0" })
local lastStat = BeastTab:CreateParagraph({ Title = "Last Set Stage", Content = "0" })

task.spawn(function()
    while task.wait(1) do
        local highest = getHighestStage()
        if highest then
            if autoRunning and highest ~= lastHighestStage then
                lastHighestStage = highest
                if beastRemote then
                    pcall(function()
                        beastRemote:FireServer(highest)
                    end)
                    lastStat:Set({
                        Title = "Last Set Stage",
                        Content = tostring(highest) .. " @ " .. os.date("%H:%M:%S"),
                    })
                end
            end
            highStat:Set({
                Title = "Highest Stage",
                Content = tostring(highest),
            })
        else
            highStat:Set({
                Title = "Highest Stage",
                Content = "✗ Không tìm thấy",
            })
        end
        beastStat:Set({
            Title = "SetBeastStage",
            Content = beastRemote and "✓ Found" or "✗ Not found",
        })
        soulStat:Set({
            Title = "SetSoulFocus",
            Content = soulFocusRemote and "✓ Found" or "✗ Not found",
        })
    end
end)

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

SpeedTab:CreateInput({
    Name = "Speed Value (16-500)",
    PlaceholderText = "Nhập số rồi Enter",
    RemoveTextAfterFocusLost = true,
    Callback = function(text)
        local num = tonumber(text)
        if num and num >= 16 and num <= 500 then
            currentSpeed = num
            if speedEnabled and not walkRunning and humanoid then
                humanoid.WalkSpeed = num
            end
            Rayfield:Notify({
                Title = "Speed",
                Content = "Đã set " .. num,
                Duration = 2,
            })
        else
            Rayfield:Notify({
                Title = "Lỗi",
                Content = "Nhập số từ 16 đến 500",
                Duration = 2,
            })
        end
    end,
})

-- ============ GUI CONTROL TAB ============
GUITab:CreateSection("Toggle GUI")

local guiIntent = { bloodlines = false, spirit = false }

GUITab:CreateToggle({
    Name = "BloodlinesGui",
    CurrentValue = false,
    Flag = "BloodlinesGuiToggle",
    Callback = function(v)
        guiIntent.bloodlines = v
        local gui = findGui("BloodlinesGui")
        forceShow(gui, v)
    end,
})

GUITab:CreateToggle({
    Name = "SpiritRootsGui",
    CurrentValue = false,
    Flag = "SpiritGuiToggle",
    Callback = function(v)
        guiIntent.spirit = v
        local gui = findGui("SpiritRootsGui")
        forceShow(gui, v)
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if guiIntent.bloodlines then
            local gui = findGui("BloodlinesGui")
            if gui then
                local current
                if gui:IsA("ScreenGui") then current = gui.Enabled
                elseif gui:IsA("GuiObject") then current = gui.Visible end
                if current ~= true then forceShow(gui, true) end
            end
        end
        if guiIntent.spirit then
            local gui = findGui("SpiritRootsGui")
            if gui then
                local current
                if gui:IsA("ScreenGui") then current = gui.Enabled
                elseif gui:IsA("GuiObject") then current = gui.Visible end
                if current ~= true then forceShow(gui, true) end
            end
        end
    end
end)

GUITab:CreateSection("Status")

local bloodStat = GUITab:CreateParagraph({ Title = "BloodlinesGui", Content = "..." })
local spiritStat = GUITab:CreateParagraph({ Title = "SpiritRootsGui", Content = "..." })

task.spawn(function()
    while task.wait(1) do
        local bg = findGui("BloodlinesGui")
        local sg = findGui("SpiritRootsGui")
        bloodStat:Set({
            Title = "BloodlinesGui",
            Content = bg and ("✓ Enabled: " .. tostring(bg.Enabled)) or "✗ Not found"
        })
        spiritStat:Set({
            Title = "SpiritRootsGui",
            Content = sg and ("✓ Enabled: " .. tostring(sg.Enabled)) or "✗ Not found"
        })
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
                "Speed: %s\nMiasma: %s\nBeast Auto: %s\nStars: %s\nAnti-AFK: %s",
                speedEnabled and "ON" or "OFF",
                spamEnabled and "ON" or "OFF",
                autoRunning and "ON" or "OFF",
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
        "Miasma: %s | Beast: %s | Folder: %s",
        status.speedRemote and "OK" or "MISS",
        (beastRemote and soulFocusRemote) and "OK" or "MISS",
        status.folder and "OK" or "MISS"
    ),
    Duration = 5,
})
