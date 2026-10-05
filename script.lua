-- SPEED HACK + AUTO SPAM - RAYFIELD UI
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

-- ===== LOAD RAYFIELD =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Onyx Hub",
    LoadingTitle = "Loading Onyx Hub",
    LoadingSubtitle = "by Onyx",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "OnyxHub",
        FileName = "Config"
    },
    KeySystem = false,
})

-- ===== VARIABLES =====
local DEFAULT_SPEED = 16
local currentSpeed = 100
local speedEnabled = false
local spamEnabled = false
local spamDelay = 0.1

-- Cache humanoid
local humanoid = nil
local function bindChar(char)
    humanoid = char:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.WalkSpeed = speedEnabled and currentSpeed or DEFAULT_SPEED
    end
end
if LP.Character then bindChar(LP.Character) end
LP.CharacterAdded:Connect(bindChar)

-- Cache remote
local miasmaRemote
do
    local ev = RS:FindFirstChild("RemoteEvents")
    if ev then miasmaRemote = ev:FindFirstChild("GainMiasma") end
end

-- ===== TABS =====
local MainTab = Window:CreateTab("Main", 4483362458)
local InfoTab = Window:CreateTab("Info", 4483362458)

-- ===== SPEED SECTION =====
MainTab:CreateSection("Speed Hack")

MainTab:CreateToggle({
    Name = "Enable Speed Hack",
    CurrentValue = false,
    Flag = "SpeedToggle",
    Callback = function(value)
        speedEnabled = value
        if humanoid then
            humanoid.WalkSpeed = speedEnabled and currentSpeed or DEFAULT_SPEED
        end
    end,
})

MainTab:CreateSlider({
    Name = "Speed Value",
    Range = {16, 500},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = 100,
    Flag = "SpeedSlider",
    Callback = function(value)
        currentSpeed = value
        if speedEnabled and humanoid then
            humanoid.WalkSpeed = value
        end
    end,
})

MainTab:CreateButton({
    Name = "Reset Speed to 100",
    Callback = function()
        currentSpeed = 100
        if speedEnabled and humanoid then
            humanoid.WalkSpeed = 100
        end
        Rayfield:Notify({
            Title = "Speed Reset",
            Content = "Speed đã về 100",
            Duration = 3,
        })
    end,
})

-- ===== SPAM SECTION =====
MainTab:CreateSection("Auto Spam GainMiasma")

MainTab:CreateToggle({
    Name = "Enable Auto Spam",
    CurrentValue = false,
    Flag = "SpamToggle",
    Callback = function(value)
        spamEnabled = value
    end,
})

MainTab:CreateSlider({
    Name = "Spam Delay (giây)",
    Range = {1, 100},
    Increment = 1,
    Suffix = "/100s",
    CurrentValue = 10,
    Flag = "SpamSlider",
    Callback = function(value)
        spamDelay = value / 100  -- 1→0.01s, 100→1s
    end,
})

MainTab:CreateButton({
    Name = "Fire Spam 1 Lần",
    Callback = function()
        if miasmaRemote then
            pcall(function() miasmaRemote:FireServer() end)
            Rayfield:Notify({
                Title = "Spam",
                Content = "Đã fire 1 lần",
                Duration = 2,
            })
        end
    end,
})

-- ===== INFO TAB =====
InfoTab:CreateParagraph({
    Title = "Status",
    Content = miasmaRemote and "Remote GainMiasma: ✓ Found" or "Remote GainMiasma: ✗ NOT FOUND",
})

InfoTab:CreateParagraph({
    Title = "Hotkeys",
    Content = "F1 = Toggle Speed\nF2 = Toggle Spam\nR = Reset Speed",
})

-- ===== SPAM LOOP =====
task.spawn(function()
    while true do
        if spamEnabled and miasmaRemote then
            pcall(function()
                miasmaRemote:FireServer()
            end)
            task.wait(spamDelay)
        else
            task.wait(0.1)
        end
    end
end)

-- ===== HOTKEYS =====
game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.F1 then
        speedEnabled = not speedEnabled
        if humanoid then
            humanoid.WalkSpeed = speedEnabled and currentSpeed or DEFAULT_SPEED
        end
        Rayfield:Notify({
            Title = "Speed",
            Content = speedEnabled and "ON" or "OFF",
            Duration = 2,
        })
    elseif k == Enum.KeyCode.F2 then
        spamEnabled = not spamEnabled
        Rayfield:Notify({
            Title = "Spam",
            Content = spamEnabled and "ON" or "OFF",
            Duration = 2,
        })
    elseif k == Enum.KeyCode.R then
        currentSpeed = 100
        if speedEnabled and humanoid then
            humanoid.WalkSpeed = 100
        end
    end
end)

-- ===== WELCOME =====
Rayfield:Notify({
    Title = "Onyx Hub",
    Content = "Đã load xong",
    Duration = 5,
})

Rayfield:LoadConfiguration()
