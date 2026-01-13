--[[
BuildClient.client.lua - COMPLETELY REFACTORED FOR FORTNITE-STYLE 3-SLOT SYSTEM
Client-side building with grid/level placement, ghost preview, validation feedback

New Architecture:
- Only 3 build pieces: Floor, Wall, Ramp (NO CEILING, NO TRAP in hotbar)
- Level-based vertical placement (shift+scroll or keybind to change level)
- Ghost preview shows valid/invalid colors
- Grid snapping with proper tile/edge positioning
- Communicates with new BuildService API
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Wait for RemoteEvents
local buildRemotes = ReplicatedStorage:WaitForChild("BuildRemotes")
local PlaceStructureRemote = buildRemotes:WaitForChild("PlaceStructure")
local DeleteStructureRemote = buildRemotes:WaitForChild("DeleteStructure")

-- Wait for BuildEvents (communication with BuildUI)
local buildEvents = ReplicatedStorage:WaitForChild("BuildEvents")
local slotSelected = buildEvents:WaitForChild("SlotSelected")
local slotDeselected = buildEvents:WaitForChild("SlotDeselected")

-- Constants
local TILE_SIZE = 12
local WALL_HEIGHT = 8
local LEVEL_HEIGHT = 8
local ROTATION_INCREMENT = 90
local MAX_BUILD_DISTANCE = 50

-- Build mode state
local buildMode = {
active = false,
selectedSlot = nil,  -- 1=floor, 2=wall, 3=ramp
currentLevel = 0,    -- Current build level (0 = ground)
rotation = 0,        -- Current rotation (0, 90, 180, 270)
ghost = nil,         -- Ghost preview part
deleteMode = false,  -- Delete mode flag
}

-- Slot configuration (3 slots only)
local SLOT_CONFIG = {
[1] = { type = "floor", size = Vector3.new(12, 1, 12), color = Color3.fromRGB(120, 200, 120), name = "Floor" },
[2] = { type = "wall", size = Vector3.new(12, 8, 1), color = Color3.fromRGB(200, 200, 120), name = "Wall" },
[3] = { type = "ramp", size = Vector3.new(12, 8, 12), color = Color3.fromRGB(150, 130, 100), name = "Ramp" },
}

print("[BuildClient] ✓✓✓ INITIALIZED - FORTNITE-STYLE 3-SLOT SYSTEM ✓✓✓")
print("[BuildClient] - 3 Build Pieces: Floor, Wall, Ramp")
print("[BuildClient] - Level-based placement (Q/E to change level)")
print("[BuildClient] - Grid snapping with validation")

-- Convert world position to grid coordinates
local function WorldToGrid(worldPos)
local x = math.floor((worldPos.X / TILE_SIZE) + 0.5) * TILE_SIZE
local z = math.floor((worldPos.Z / TILE_SIZE) + 0.5) * TILE_SIZE
local level = buildMode.currentLevel
local y = 0.5 + (level * LEVEL_HEIGHT)
return Vector3.new(x, y, z), x, z, level
end

-- Determine which edge of a tile we're closest to (for walls)
local function DetermineWallEdge(worldPos, gridX, gridZ)
local tileCenter = Vector3.new(gridX, 0, gridZ)
local relative = worldPos - tileCenter

-- Determine which edge is closest
local absX = math.abs(relative.X)
local absZ = math.abs(relative.Z)

if absX > absZ then
-- Closer to X edges
if relative.X > 0 then
return "east", Vector3.new(gridX + TILE_SIZE/2, 0, gridZ), 90
else
return "west", Vector3.new(gridX - TILE_SIZE/2, 0, gridZ), 270
end
else
-- Closer to Z edges
if relative.Z > 0 then
return "north", Vector3.new(gridX, 0, gridZ + TILE_SIZE/2), 0
else
return "south", Vector3.new(gridX, 0, gridZ - TILE_SIZE/2), 180
end
end
end

-- Create or update ghost preview
local function UpdateGhost()
-- Remove old ghost
if buildMode.ghost then
buildMode.ghost:Destroy()
buildMode.ghost = nil
end

if not buildMode.active or not buildMode.selectedSlot or buildMode.deleteMode then
return
end

-- Get mouse target position
local mouseTarget = mouse.Hit.Position
local config = SLOT_CONFIG[buildMode.selectedSlot]

if not config then
return
end

-- Convert to grid position
local gridPos, gridX, gridZ, level = WorldToGrid(mouseTarget)

print(string.format("[BuildClient] Ghost update: slot=%d, grid=(%d,%d,%d), rotation=%d", 
buildMode.selectedSlot, gridX, gridZ, level, buildMode.rotation))

local ghost
local finalPos = gridPos
local finalRotation = buildMode.rotation

-- Create ghost based on type
if config.type == "wall" then
-- Walls snap to edges
local edge, edgePos, edgeRotation = DetermineWallEdge(mouseTarget, gridX, gridZ)
finalPos = Vector3.new(edgePos.X, gridPos.Y + WALL_HEIGHT/2, edgePos.Z)
finalRotation = edgeRotation

ghost = Instance.new("Part")
ghost.Size = config.size
print(string.format("[BuildClient] Wall ghost: edge=%s, pos=(%.1f,%.1f,%.1f)", edge, finalPos.X, finalPos.Y, finalPos.Z))

elseif config.type == "ramp" then
-- Ramps use WedgePart
ghost = Instance.new("WedgePart")
ghost.Size = config.size
finalPos = gridPos + Vector3.new(0, WALL_HEIGHT/2, 0)  -- Center at mid-height
print(string.format("[BuildClient] Ramp ghost: pos=(%.1f,%.1f,%.1f), rotation=%d", finalPos.X, finalPos.Y, finalPos.Z, finalRotation))

else  -- floor
ghost = Instance.new("Part")
ghost.Size = config.size
print(string.format("[BuildClient] Floor ghost: pos=(%.1f,%.1f,%.1f)", finalPos.X, finalPos.Y, finalPos.Z))
end

-- Common ghost properties
ghost.Name = "BuildGhost"
ghost.Position = finalPos
ghost.Anchored = true
ghost.CanCollide = false
ghost.Transparency = 0.5
ghost.Material = Enum.Material.SmoothPlastic

-- Check if within build distance
local character = player.Character
local inRange = false
if character then
local rootPart = character:FindFirstChild("HumanoidRootPart")
if rootPart then
local distance = (rootPart.Position - finalPos).Magnitude
inRange = distance <= MAX_BUILD_DISTANCE
end
end

-- Color based on validity (green if in range, red if not)
-- Server will do full validation, this is just for range
if inRange then
ghost.Color = Color3.fromRGB(100, 255, 100)  -- Green
print("[BuildClient] Ghost: IN RANGE (green)")
else
ghost.Color = Color3.fromRGB(255, 100, 100)  -- Red
print("[BuildClient] Ghost: OUT OF RANGE (red)")
end

-- Apply rotation
ghost.CFrame = CFrame.new(finalPos) * CFrame.Angles(0, math.rad(finalRotation), 0)

ghost.Parent = workspace
buildMode.ghost = ghost
end

-- Handle slot selection from UI
slotSelected.Event:Connect(function(slotNumber)
print(string.format("[BuildClient] ======== SLOT SELECTED: %d ========", slotNumber))

buildMode.active = true
buildMode.selectedSlot = slotNumber
buildMode.deleteMode = false

local config = SLOT_CONFIG[slotNumber]
if config then
print(string.format("[BuildClient] Selected: %s", config.name))
end

UpdateGhost()
end)

-- Handle slot deselection from UI
slotDeselected.Event:Connect(function()
print("[BuildClient] ======== SLOT DESELECTED ========")

buildMode.active = false
buildMode.selectedSlot = nil
buildMode.deleteMode = false

if buildMode.ghost then
buildMode.ghost:Destroy()
buildMode.ghost = nil
end
end)

-- Handle delete mode toggle
local deleteToggle = buildEvents:FindFirstChild("DeleteModeToggle")
if deleteToggle then
deleteToggle.Event:Connect(function(enabled)
print(string.format("[BuildClient] ======== DELETE MODE: %s ========", enabled and "ENABLED" or "DISABLED"))

buildMode.deleteMode = enabled

if enabled then
buildMode.active = false
buildMode.selectedSlot = nil
if buildMode.ghost then
buildMode.ghost:Destroy()
buildMode.ghost = nil
end
end
end)
end

-- Mouse input handling
mouse.Move:Connect(function()
if buildMode.active and not buildMode.deleteMode then
UpdateGhost()
end
end)

-- Click to place or delete
mouse.Button1Down:Connect(function()
if buildMode.deleteMode then
-- Delete mode: click on structure to delete
local target = mouse.Target
if target and target.Parent and target:FindFirstChild("GridX") or target:GetAttribute("GridX") then
print(string.format("[BuildClient] ======== DELETE CLICK ========"))
print(string.format("[BuildClient] Target: %s", target.Name))

DeleteStructureRemote:FireServer(target)
else
print("[BuildClient] Delete click: no valid structure targeted")
end
return
end

if not buildMode.active or not buildMode.selectedSlot then
return
end

local config = SLOT_CONFIG[buildMode.selectedSlot]
if not config then
return
end

-- Get placement position
local mouseTarget = mouse.Hit.Position
local gridPos, gridX, gridZ, level = WorldToGrid(mouseTarget)

print(string.format("[BuildClient] ======== PLACE CLICK ========"))
print(string.format("[BuildClient] Type: %s", config.type))
print(string.format("[BuildClient] Grid: (%d, %d, %d)", gridX, gridZ, level))
print(string.format("[BuildClient] Rotation: %d", buildMode.rotation))

-- Send to server
PlaceStructureRemote:FireServer(config.type, gridPos, buildMode.rotation)
end)

-- Keyboard input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
if gameProcessed then return end

-- R = Rotate
if input.KeyCode == Enum.KeyCode.R then
buildMode.rotation = (buildMode.rotation + ROTATION_INCREMENT) % 360
print(string.format("[BuildClient] Rotation changed: %d degrees", buildMode.rotation))
UpdateGhost()

-- Q = Level down
elseif input.KeyCode == Enum.KeyCode.Q then
buildMode.currentLevel = math.max(0, buildMode.currentLevel - 1)
print(string.format("[BuildClient] Level changed: %d", buildMode.currentLevel))
UpdateGhost()

-- E = Level up
elseif input.KeyCode == Enum.KeyCode.E then
buildMode.currentLevel = buildMode.currentLevel + 1
print(string.format("[BuildClient] Level changed: %d", buildMode.currentLevel))
UpdateGhost()

-- ESC = Deselect
elseif input.KeyCode == Enum.KeyCode.Escape then
if buildMode.active or buildMode.deleteMode then
print("[BuildClient] ESC pressed - deselecting")
slotDeselected:Fire()
end
end
end)

-- Update ghost continuously during RenderStepped for smooth movement
RunService.RenderStepped:Connect(function()
if buildMode.active and buildMode.ghost and not buildMode.deleteMode then
UpdateGhost()
end
end)

print("[BuildClient] ✓ Event handlers connected")
print("[BuildClient] Controls:")
print("[BuildClient]   - Click hotbar or press 1/2/3 to select piece")
print("[BuildClient]   - R to rotate")
print("[BuildClient]   - Q/E to change build level")
print("[BuildClient]   - Left click to place")
print("[BuildClient]   - ESC to cancel")
