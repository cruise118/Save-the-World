--[[
    Portal System UI - Client Script
    Handles UI for portal creation and management
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

-- Configuration
local STATUS_MESSAGE_DURATION = 3 -- seconds

-- Wait for RemoteEvent
local portalEvent = ReplicatedStorage:WaitForChild("PortalEvent", 10)
if not portalEvent then
    warn("PortalEvent not found in ReplicatedStorage")
    return
end

-- Wait for UI
local portalGui = playerGui:WaitForChild("PortalGui", 10)
if not portalGui then
    warn("PortalGui not found")
    return
end

local mainFrame = portalGui:WaitForChild("MainFrame")
local createButton = mainFrame:WaitForChild("CreateButton")
local removeButton = mainFrame:WaitForChild("RemoveButton")
local listButton = mainFrame:WaitForChild("ListButton")
local statusLabel = mainFrame:WaitForChild("StatusLabel")
local portalListFrame = mainFrame:WaitForChild("PortalListFrame")
local portalListContainer = portalListFrame:WaitForChild("Container")

-- State
local isSettingEntry = false
local isSettingExit = false
local entryPosition = nil
local entryRotation = 0
local selectedPortalId = nil

-- Update status label
local function updateStatus(text, color)
    statusLabel.Text = text
    statusLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    task.delay(STATUS_MESSAGE_DURATION, function()
        if statusLabel.Text == text then
            statusLabel.Text = "Ready"
            statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
end

-- Clear portal list UI
local function clearPortalList()
    for _, child in pairs(portalListContainer:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

-- Update portal list UI
local function updatePortalList(portalList)
    clearPortalList()
    
    if not portalList or #portalList == 0 then
        local noPortalsLabel = Instance.new("TextLabel")
        noPortalsLabel.Name = "NoPortals"
        noPortalsLabel.Size = UDim2.new(1, -10, 0, 30)
        noPortalsLabel.Position = UDim2.new(0, 5, 0, 5)
        noPortalsLabel.BackgroundTransparency = 1
        noPortalsLabel.Text = "No portals found"
        noPortalsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        noPortalsLabel.Font = Enum.Font.Gotham
        noPortalsLabel.TextSize = 14
        noPortalsLabel.Parent = portalListContainer
        return
    end
    
    for i, portalData in ipairs(portalList) do
        local button = Instance.new("TextButton")
        button.Name = "Portal_" .. i
        button.Size = UDim2.new(1, -10, 0, 30)
        button.Position = UDim2.new(0, 5, 0, 5 + (i - 1) * 35)
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.Text = string.format("Portal %d", i)
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.Gotham
        button.TextSize = 14
        button.Parent = portalListContainer
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = button
        
        button.MouseButton1Click:Connect(function()
            selectedPortalId = portalData.id
            updateStatus("Portal selected: " .. i, Color3.fromRGB(100, 255, 100))
            
            -- Highlight selected
            for _, btn in pairs(portalListContainer:GetChildren()) do
                if btn:IsA("TextButton") then
                    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                end
            end
            button.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
        end)
    end
    
    -- Adjust container size
    portalListContainer.CanvasSize = UDim2.new(0, 0, 0, #portalList * 35 + 10)
end

-- Handle create button
createButton.MouseButton1Click:Connect(function()
    if isSettingEntry or isSettingExit then
        -- Cancel
        isSettingEntry = false
        isSettingExit = false
        entryPosition = nil
        updateStatus("Cancelled", Color3.fromRGB(255, 200, 100))
        return
    end
    
    -- Start portal creation
    isSettingEntry = true
    updateStatus("Click to set ENTRY position", Color3.fromRGB(100, 200, 255))
    createButton.Text = "Cancel"
end)

-- Handle mouse click for portal placement
mouse.Button1Down:Connect(function()
    if isSettingEntry then
        -- Set entry position
        entryPosition = mouse.Hit.Position
        entryRotation = 0
        isSettingEntry = false
        isSettingExit = true
        updateStatus("Click to set EXIT position", Color3.fromRGB(255, 150, 100))
        
    elseif isSettingExit then
        -- Set exit position and create portal
        local exitPosition = mouse.Hit.Position
        local exitRotation = 0
        
        isSettingExit = false
        createButton.Text = "Create Portal"
        
        -- Send to server
        portalEvent:FireServer("create", entryPosition, entryRotation, exitPosition, exitRotation)
        updateStatus("Creating portal...", Color3.fromRGB(255, 255, 100))
        
        entryPosition = nil
    end
end)

-- Handle remove button
removeButton.MouseButton1Click:Connect(function()
    if not selectedPortalId then
        updateStatus("Select a portal first", Color3.fromRGB(255, 100, 100))
        return
    end
    
    portalEvent:FireServer("remove", selectedPortalId)
    updateStatus("Removing portal...", Color3.fromRGB(255, 200, 100))
    selectedPortalId = nil
end)

-- Handle list button
listButton.MouseButton1Click:Connect(function()
    portalListFrame.Visible = not portalListFrame.Visible
    if portalListFrame.Visible then
        portalEvent:FireServer("list")
        updateStatus("Loading portals...", Color3.fromRGB(100, 200, 255))
    end
end)

-- Handle server responses
portalEvent.OnClientEvent:Connect(function(action, data)
    if action == "created" then
        updateStatus("Portal created!", Color3.fromRGB(100, 255, 100))
        -- Refresh list if open
        if portalListFrame.Visible then
            portalEvent:FireServer("list")
        end
        
    elseif action == "removed" then
        updateStatus("Portal removed!", Color3.fromRGB(100, 255, 100))
        selectedPortalId = nil
        -- Refresh list if open
        if portalListFrame.Visible then
            portalEvent:FireServer("list")
        end
        
    elseif action == "error" then
        updateStatus("Error: " .. tostring(data), Color3.fromRGB(255, 100, 100))
        
    elseif action == "portalList" then
        updatePortalList(data)
        updateStatus("Portals loaded", Color3.fromRGB(100, 255, 100))
    end
end)

-- Cancel portal placement on ESC
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Escape then
        if isSettingEntry or isSettingExit then
            isSettingEntry = false
            isSettingExit = false
            entryPosition = nil
            createButton.Text = "Create Portal"
            updateStatus("Cancelled", Color3.fromRGB(255, 200, 100))
        end
    end
end)

print("Portal System UI initialized")
