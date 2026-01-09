--[[
    Size Control UI - Client Script
    Handles UI interactions for player size control
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for RemoteEvent to be created
local sizeControlEvent = ReplicatedStorage:WaitForChild("SizeControlEvent", 10)
if not sizeControlEvent then
    warn("SizeControlEvent not found in ReplicatedStorage")
    return
end

-- Wait for UI to load
local sizeControlGui = playerGui:WaitForChild("SizeControlGui", 10)
if not sizeControlGui then
    warn("SizeControlGui not found")
    return
end

local mainFrame = sizeControlGui:WaitForChild("MainFrame")
local increaseButton = mainFrame:WaitForChild("IncreaseButton")
local decreaseButton = mainFrame:WaitForChild("DecreaseButton")
local sizeLabel = mainFrame:WaitForChild("SizeLabel")

-- Current size display
local currentSize = 1

-- Update size label
local function updateSizeLabel(size)
    currentSize = size
    sizeLabel.Text = string.format("Size: %.1fx", size)
end

-- Button click handlers
increaseButton.MouseButton1Click:Connect(function()
    sizeControlEvent:FireServer("increase")
end)

decreaseButton.MouseButton1Click:Connect(function()
    sizeControlEvent:FireServer("decrease")
end)

-- Listen for size updates from server
sizeControlEvent.OnClientEvent:Connect(function(action, newSize)
    if action == "updateSize" then
        updateSizeLabel(newSize)
    elseif action == "error" then
        warn("Size control error: " .. tostring(newSize))
    end
end)

-- Initialize with current size
updateSizeLabel(1)

print("Size Control UI initialized")
