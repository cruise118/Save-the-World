--[[
    Portal System Server
    Manages portal creation, teleportation, and removal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

-- Configuration
local TELEPORT_COOLDOWN = 3 -- seconds
local PORTAL_SIZE = Vector3.new(6, 8, 0.5)
local PORTAL_COLOR_ENTRY = Color3.fromRGB(100, 200, 255)
local PORTAL_COLOR_EXIT = Color3.fromRGB(255, 150, 100)

-- Create folder for portals in workspace
local portalsFolder = Workspace:FindFirstChild("Portals") or Instance.new("Folder")
portalsFolder.Name = "Portals"
portalsFolder.Parent = Workspace

-- Create RemoteEvents
local portalEvent = Instance.new("RemoteEvent")
portalEvent.Name = "PortalEvent"
portalEvent.Parent = ReplicatedStorage

-- Store portal data
local portalPairs = {} -- {portalId = {entry = part, exit = part, creatorId = userId}}
local playerCooldowns = {} -- {userId = tick()}
local playersInPortal = {} -- {userId = portalId}

-- Generate unique portal ID
local function generatePortalId()
    return "Portal_" .. HttpService:GenerateGUID(false)
end

-- Create a portal part
local function createPortalPart(position, rotation, isEntry, portalId)
    local portal = Instance.new("Part")
    portal.Name = isEntry and "Entry_" .. portalId or "Exit_" .. portalId
    portal.Size = PORTAL_SIZE
    portal.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    portal.Anchored = true
    portal.CanCollide = false
    portal.Color = isEntry and PORTAL_COLOR_ENTRY or PORTAL_COLOR_EXIT
    portal.Material = Enum.Material.Neon
    portal.Transparency = 0.3
    portal.Parent = portalsFolder
    
    -- Add attributes for identification
    portal:SetAttribute("PortalId", portalId)
    portal:SetAttribute("IsEntry", isEntry)
    
    -- Add selection box for visibility
    local selectionBox = Instance.new("SelectionBox")
    selectionBox.Adornee = portal
    selectionBox.Color3 = portal.Color
    selectionBox.LineThickness = 0.05
    selectionBox.Parent = portal
    
    -- Add touch detection
    local touchPart = Instance.new("Part")
    touchPart.Name = "TouchDetector"
    touchPart.Size = PORTAL_SIZE * 1.2
    touchPart.CFrame = portal.CFrame
    touchPart.Anchored = true
    touchPart.CanCollide = false
    touchPart.Transparency = 1
    touchPart.Parent = portal
    
    return portal
end

-- Teleport player through portal
local function teleportPlayer(player, fromPortal, toPortal)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local humanoidRootPart = character.HumanoidRootPart
    
    -- Check cooldown
    local lastTeleport = playerCooldowns[player.UserId] or 0
    if tick() - lastTeleport < TELEPORT_COOLDOWN then
        return false
    end
    
    -- Teleport
    local offset = toPortal.CFrame.LookVector * 5
    humanoidRootPart.CFrame = toPortal.CFrame + offset
    
    -- Set cooldown
    playerCooldowns[player.UserId] = tick()
    playersInPortal[player.UserId] = nil
    
    return true
end

-- Handle touch events for portals
local function setupPortalTouch(portal, portalId)
    local touchDetector = portal:FindFirstChild("TouchDetector")
    if not touchDetector then return end
    
    touchDetector.Touched:Connect(function(hit)
        if not hit.Parent or not hit.Parent:FindFirstChild("Humanoid") then
            return
        end
        
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if not player then return end
        
        -- Prevent rapid re-teleports
        if playersInPortal[player.UserId] == portalId then
            return
        end
        
        -- Find the paired portal
        local portalData = portalPairs[portalId]
        if not portalData then return end
        
        local isEntry = portal:GetAttribute("IsEntry")
        local targetPortal = isEntry and portalData.exit or portalData.entry
        
        if targetPortal and targetPortal.Parent then
            playersInPortal[player.UserId] = portalId
            if teleportPlayer(player, portal, targetPortal) then
                print(string.format("%s teleported through portal %s", player.Name, portalId))
            end
            
            -- Clear portal tracking after cooldown
            task.delay(TELEPORT_COOLDOWN, function()
                if playersInPortal[player.UserId] == portalId then
                    playersInPortal[player.UserId] = nil
                end
            end)
        end
    end)
end

-- Create a portal pair
local function createPortal(player, entryPosition, entryRotation, exitPosition, exitRotation)
    if not player then return nil end
    
    local portalId = generatePortalId()
    
    -- Create entry and exit portals
    local entry = createPortalPart(entryPosition, entryRotation, true, portalId)
    local exit = createPortalPart(exitPosition, exitRotation, false, portalId)
    
    -- Store portal data
    portalPairs[portalId] = {
        entry = entry,
        exit = exit,
        creatorId = player.UserId,
        created = tick()
    }
    
    -- Setup touch detection
    setupPortalTouch(entry, portalId)
    setupPortalTouch(exit, portalId)
    
    return portalId
end

-- Remove a portal pair
local function removePortal(portalId, requestingPlayer)
    local portalData = portalPairs[portalId]
    if not portalData then
        return false, "Portal not found"
    end
    
    -- Check permissions (only creator or admin can remove)
    if requestingPlayer and portalData.creatorId ~= requestingPlayer.UserId then
        -- Could add admin check here
        return false, "No permission to remove this portal"
    end
    
    -- Clean up portal parts
    if portalData.entry and portalData.entry.Parent then
        portalData.entry:Destroy()
    end
    if portalData.exit and portalData.exit.Parent then
        portalData.exit:Destroy()
    end
    
    -- Remove from storage
    portalPairs[portalId] = nil
    
    -- Clear any players tracked in this portal
    for userId, trackedPortalId in pairs(playersInPortal) do
        if trackedPortalId == portalId then
            playersInPortal[userId] = nil
        end
    end
    
    return true, "Portal removed"
end

-- Handle portal events from client
portalEvent.OnServerEvent:Connect(function(player, action, ...)
    if action == "create" then
        local entryPos, entryRot, exitPos, exitRot = ...
        
        -- Validate positions
        if type(entryPos) ~= "Vector3" or type(exitPos) ~= "Vector3" then
            portalEvent:FireClient(player, "error", "Invalid portal positions")
            return
        end
        
        local portalId = createPortal(player, entryPos, entryRot or 0, exitPos, exitRot or 0)
        if portalId then
            portalEvent:FireClient(player, "created", portalId)
            print(string.format("%s created portal %s", player.Name, portalId))
        else
            portalEvent:FireClient(player, "error", "Failed to create portal")
        end
        
    elseif action == "remove" then
        local portalId = ...
        
        if not portalId then
            portalEvent:FireClient(player, "error", "No portal ID provided")
            return
        end
        
        local success, message = removePortal(portalId, player)
        if success then
            portalEvent:FireClient(player, "removed", portalId)
            print(string.format("%s removed portal %s", player.Name, portalId))
        else
            portalEvent:FireClient(player, "error", message)
        end
        
    elseif action == "list" then
        -- Send list of all portals to client
        local portalList = {}
        for portalId, data in pairs(portalPairs) do
            table.insert(portalList, {
                id = portalId,
                creatorId = data.creatorId,
                entryPos = data.entry and data.entry.Position or Vector3.new(),
                exitPos = data.exit and data.exit.Position or Vector3.new()
            })
        end
        portalEvent:FireClient(player, "portalList", portalList)
    end
end)

-- Clean up on player leaving
Players.PlayerRemoving:Connect(function(player)
    playerCooldowns[player.UserId] = nil
    playersInPortal[player.UserId] = nil
end)

-- Periodic cleanup of invalid portals
task.spawn(function()
    while true do
        task.wait(60) -- Check every minute
        
        for portalId, data in pairs(portalPairs) do
            -- Check if portal parts still exist
            if not data.entry or not data.entry.Parent or not data.exit or not data.exit.Parent then
                print("Cleaning up invalid portal: " .. portalId)
                removePortal(portalId, nil)
            end
        end
    end
end)

print("Portal System Server initialized")
