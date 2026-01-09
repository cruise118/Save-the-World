--[[
    Rojo Setup Test Script
    This script makes your character big to test that Rojo is working correctly
]]

print("Rojo test script loaded!")

-- Function to make a character big
local function makeCharacterBig(character)
    -- Wait for the humanoid to load
    local humanoid = character:WaitForChild("Humanoid")
    
    -- Scale up the character to 3x normal size
    local scaleValue = 3
    
    -- Check if BodyHeightScale exists (R15) or scale all parts (R6)
    local bodyHeightScale = humanoid:FindFirstChild("BodyHeightScale")
    local bodyWidthScale = humanoid:FindFirstChild("BodyWidthScale")
    local bodyDepthScale = humanoid:FindFirstChild("BodyDepthScale")
    
    if bodyHeightScale then
        -- R15 character - use scale values
        bodyHeightScale.Value = scaleValue
        bodyWidthScale.Value = scaleValue
        bodyDepthScale.Value = scaleValue
        print("Made " .. character.Name .. " BIG! (R15)")
    else
        -- R6 character - manually scale all body parts
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Size = part.Size * scaleValue
            end
        end
        -- Also increase walk speed to match the larger size
        humanoid.WalkSpeed = humanoid.WalkSpeed * scaleValue
        print("Made " .. character.Name .. " BIG! (R6)")
    end
end

-- Function to handle player joining
local function onPlayerAdded(player)
    print("Player joined: " .. player.Name)
    
    -- Make their character big when it spawns
    player.CharacterAdded:Connect(function(character)
        makeCharacterBig(character)
    end)
    
    -- Also handle if they already have a character
    if player.Character then
        makeCharacterBig(player.Character)
    end
end

-- Connect to all players joining
game.Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle players already in the game (for testing in Studio)
for _, player in pairs(game.Players:GetPlayers()) do
    onPlayerAdded(player)
end

print("Character scaling script ready! Players will be BIG!")