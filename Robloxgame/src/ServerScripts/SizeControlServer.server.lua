--[[
    Size Control Server
    Handles player size changes with validation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration
local MIN_SIZE = 0.5
local MAX_SIZE = 5.0
local SIZE_STEP = 0.5

-- Create RemoteEvent for client-server communication
local sizeControlEvent = Instance.new("RemoteEvent")
sizeControlEvent.Name = "SizeControlEvent"
sizeControlEvent.Parent = ReplicatedStorage

-- Store player sizes
local playerSizes = {}

-- Function to apply size to character
local function applySize(character, sizeValue)
    if not character or not character:FindFirstChild("Humanoid") then
        return false
    end
    
    local humanoid = character.Humanoid
    
    -- Check for R15 (has BodyHeightScale)
    local bodyHeightScale = humanoid:FindFirstChild("BodyHeightScale")
    local bodyWidthScale = humanoid:FindFirstChild("BodyWidthScale")
    local bodyDepthScale = humanoid:FindFirstChild("BodyDepthScale")
    
    if bodyHeightScale and bodyWidthScale and bodyDepthScale then
        -- R15 character
        bodyHeightScale.Value = sizeValue
        bodyWidthScale.Value = sizeValue
        bodyDepthScale.Value = sizeValue
    else
        -- R6 character - scale parts
        local currentSize = humanoid:GetAttribute("CurrentSize") or 1
        local scaleFactor = sizeValue / currentSize
        
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Size = part.Size * scaleFactor
            end
        end
        humanoid.WalkSpeed = 16 * sizeValue
    end
    
    humanoid:SetAttribute("CurrentSize", sizeValue)
    return true
end

-- Function to handle size change requests
local function changeSizeHandler(player, action)
    -- Validate player
    if not player or not player:IsA("Player") then
        return
    end
    
    local character = player.Character
    if not character or not character:FindFirstChild("Humanoid") then
        sizeControlEvent:FireClient(player, "error", "Character not found")
        return
    end
    
    -- Get current size
    local currentSize = playerSizes[player.UserId] or 1
    
    -- Calculate new size
    local newSize = currentSize
    if action == "increase" then
        newSize = math.min(currentSize + SIZE_STEP, MAX_SIZE)
    elseif action == "decrease" then
        newSize = math.max(currentSize - SIZE_STEP, MIN_SIZE)
    else
        sizeControlEvent:FireClient(player, "error", "Invalid action")
        return
    end
    
    -- Check if size would actually change
    if newSize == currentSize then
        sizeControlEvent:FireClient(player, "error", "Size limit reached")
        return
    end
    
    -- Apply the new size
    if applySize(character, newSize) then
        playerSizes[player.UserId] = newSize
        sizeControlEvent:FireClient(player, "updateSize", newSize)
        print(string.format("Changed %s's size to %.1fx", player.Name, newSize))
    else
        sizeControlEvent:FireClient(player, "error", "Failed to apply size")
    end
end

-- Handle character respawn
local function onCharacterAdded(character, player)
    -- Wait for humanoid
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then
        return
    end
    
    -- Reapply stored size
    local storedSize = playerSizes[player.UserId] or 1
    if storedSize ~= 1 then
        task.wait(0.1) -- Small delay to let character fully load
        applySize(character, storedSize)
        sizeControlEvent:FireClient(player, "updateSize", storedSize)
    end
end

-- Handle player joining
local function onPlayerAdded(player)
    -- Initialize player size
    playerSizes[player.UserId] = 1
    
    -- Handle current character if exists
    if player.Character then
        onCharacterAdded(player.Character, player)
    end
    
    -- Handle future characters
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(character, player)
    end)
end

-- Handle player leaving
local function onPlayerRemoving(player)
    -- Clean up stored size
    playerSizes[player.UserId] = nil
end

-- Connect events
sizeControlEvent.OnServerEvent:Connect(changeSizeHandler)
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game
for _, player in pairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

print("Size Control Server initialized")
