-- ONYX HUB - STARS RANDOM
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RS = game:GetService("ReplicatedStorage")

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
    speedRemote = false,
    folder = false,
    teleportPart = false,
    starCount = 0,
    charReady = false,
    remotePath = "?",
    folderPath = "?",
    teleportPath = "?",
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
    if tick() - cacheTime > CACHE_TTL then
        refreshCache()
    end
    return starCache
end

-- Pick star ngẫu nhiên
local function pickRandom()
    local cache = getCache()
    -- Lọc star nào còn tồn tại
    local valid = {}
    for _, entry in ipairs(cache) do
        if entry.star.Parent then
            valid[#valid + 1] = entry
        end
    end
    if #valid == 0 then return nil, nil end
    local picked = valid[math.random(1, #valid)]
    return picked.star, picked.pos
end

local function teleportToStart()
    if not teleportPart or not teleportPart.Parent then
        teleportPart = checkTeleportPart()
    end
    if not teleportPart then
        Rayfield:Notify({
            Title = "Teleport",
            Content = "✗ Part không tìm thấy",
            Duration = 3,
        })
        return false
    end
    local char = LP.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.CFrame = CFrame.new(teleportPart.Position + Vector3.new(0, teleportPart.Size.Y/2 + 3, 0))
    return true
end

local function startWalk()
    if walkRunning then return end
    local ok = teleportToStart()
    if ok then
        Rayfield:Notify({
            Title = "Stars",
            Content = "Đã teleport, bắt đầu lụm random",
            Duration = 3,
        })
    else
        Rayfield:Notify({
            Title = "Stars",
            Content = "Teleport fail, vẫn bắt đầu",
            Duration = 3,
        })
    end
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
            -- Không visited, loop lại pick random tiếp
        end
    end)
end

local function stopWalk()
    walkRunning = false
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.RootPart then hum:MoveTo(hum.RootPart.Position) end
    end
end

-- ===== TABS =====
local StarsTab = Window:CreateTab("Stars", 4483362458)
local MiasmaTab = Window:CreateTab("Miasma", 4483362458)
local SpeedTab = Window:CreateTab("Speed", 4483362458)
local StatusTab = Window:CreateTab("Status", 4483362458)

-- ============ STARS TAB ============
StarsTab:CreateSection("Auto Collect Star (Random)")

StarsTab:CreateToggle({
    Name = "Bật Auto Walk (random star)",
    CurrentValue = false,
    Flag = "WalkToggle",
    Callback = function(v)
        if v then
            startWalk()
        else
            stopWalk()
        end
    end,
})

StarsTab:CreateSection("Tuning")

StarsTab:CreateSlider({
    Name = "Walk Speed (đi bộ)",
    Range = {16, 100}, Increment = 1, Suffix = "s/s",
    CurrentValue = 25, Flag = "WalkSpeedSlider",
    Callback = function(v)
        walkSpeed = v
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
            Rayfield:Notify({Title = "Miasma", Content = "Fired 1x", Duration = 2})
        else
            Rayfield:Notify({Title = "Error", Content = "Remote không tìm thấy", Duration = 2})
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
        if humanoid then
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
        if speedEnabled and humanoid then
            humanoid.WalkSpeed = v
        end
    end,
})

SpeedTab:CreateButton({
    Name = "Reset về 100",
    Callback = function()
        currentSpeed = 100
        if speedEnabled and humanoid then
            humanoid.WalkSpeed = 100
        end
        Rayfield:Notify({Title = "Speed", Content = "Reset 100", Duration = 2})
    end,
})

-- ============ STATUS TAB ============
StatusTab:CreateSection("System Status")

local remoteStat = StatusTab:CreateParagraph({
    Title = "GainMiasma Remote",
    Content = "Đang check...",
})

local folderStat = StatusTab:CreateParagraph({
    Title = "Star Folder",
    Content = "Đang check...",
})

local tpStat = StatusTab:CreateParagraph({
    Title = "Teleport Part",
    Content = "Đang check...",
})

local charStat = StatusTab:CreateParagraph({
    Title = "Character",
    Content = "Đang check...",
})

local activeStat = StatusTab:CreateParagraph({
    Title = "Active Features",
    Content = "Đang check...",
})

local starStat = StatusTab:CreateParagraph({
    Title = "Live Star Count",
    Content = "0",
})

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
                "Speed: %s\nMiasma: %s\nStars: %s",
                speedEnabled and "ON" or "OFF",
                spamEnabled and "ON" or "OFF",
                walkRunning and "ON" or "OFF"
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
    Duration = 5,
})
