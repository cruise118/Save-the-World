--[[
    Size Control UI - Client Script
    Handles UI interactions for player size control and creates the UI programmatically
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

-- Create the UI programmatically
local function createUI()
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SizeControlGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.AnchorPoint = Vector2.new(0, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainFrame.BackgroundTransparency = 0.2
    mainFrame.BorderSizePixel = 2
    mainFrame.Position = UDim2.new(0, 10, 0.5, 0)
    mainFrame.Size = UDim2.new(0, 150, 0, 120)
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Size Label
    local sizeLabel = Instance.new("TextLabel")
    sizeLabel.Name = "SizeLabel"
    sizeLabel.BackgroundTransparency = 1
    sizeLabel.Position = UDim2.new(0, 0, 0, 10)
    sizeLabel.Size = UDim2.new(1, 0, 0, 30)
    sizeLabel.Font = Enum.Font.GothamBold
    sizeLabel.Text = "Size: 1.0x"
    sizeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    sizeLabel.TextSize = 18
    sizeLabel.Parent = mainFrame
    
    -- Increase Button
    local increaseButton = Instance.new("TextButton")
    increaseButton.Name = "IncreaseButton"
    increaseButton.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
    increaseButton.Position = UDim2.new(0.1, 0, 0, 50)
    increaseButton.Size = UDim2.new(0.8, 0, 0, 25)
    increaseButton.Font = Enum.Font.GothamBold
    increaseButton.Text = "+ Increase"
    increaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    increaseButton.TextSize = 16
    increaseButton.Parent = mainFrame
    
    local increaseCorner = Instance.new("UICorner")
    increaseCorner.CornerRadius = UDim.new(0, 6)
    increaseCorner.Parent = increaseButton
    
    -- Decrease Button
    local decreaseButton = Instance.new("TextButton")
    decreaseButton.Name = "DecreaseButton"
    decreaseButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    decreaseButton.Position = UDim2.new(0.1, 0, 0, 85)
    decreaseButton.Size = UDim2.new(0.8, 0, 0, 25)
    decreaseButton.Font = Enum.Font.GothamBold
    decreaseButton.Text = "- Decrease"
    decreaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    decreaseButton.TextSize = 16
    decreaseButton.Parent = mainFrame
    
    local decreaseCorner = Instance.new("UICorner")
    decreaseCorner.CornerRadius = UDim.new(0, 6)
    decreaseCorner.Parent = decreaseButton
    
    return screenGui, increaseButton, decreaseButton, sizeLabel
end

-- Create the UI
local sizeControlGui, increaseButton, decreaseButton, sizeLabel = createUI()

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
