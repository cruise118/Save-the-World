--[[
BuildService.lua - COMPLETELY REFACTORED FOR FORTNITE-STYLE GRID/LEVEL SYSTEM
Server-authoritative building with grid-based placement, structural support, cascade destruction

New Architecture:
- Integrates BuildGridService for grid/occupancy
- Integrates BuildSupportService for structural validation
- Integrates TerrainSupportService for terrain support
- Integrates BuildPlacementService for validation
- Integrates BuildPieceFactory for spawning
- NO CEILING STRUCTURE (use stacked floors)
- Only Floor, Wall, Ramp pieces
- Full metadata storage for AI pathfinding

Usage:
local BuildService = require(...BuildService)
local service = BuildService.new(gridService, supportService, terrainService, placementService, factoryService)
local success, part, err = service:PlaceFloor(player, x, z, level, rotation)
--]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local BuildService = {}
BuildService.__index = BuildService

-- Create new BuildService with all dependencies
function BuildService.new(buildGridService, buildSupportService, terrainSupportService, buildPlacementService, buildPieceFactory, config)
assert(RunService:IsServer(), "BuildService must run on server")

local self = setmetatable({}, BuildService)

-- Inject dependencies
self.gridService = buildGridService
self.supportService = buildSupportService
self.terrainService = terrainSupportService
self.placementService = buildPlacementService
self.factory = buildPieceFactory

-- Config
self.config = config or {}
self.config.maxBuildDistance = self.config.maxBuildDistance or 50
self.config.debug = self.config.debug or true

-- Track floor trap placements (for future trap system)
self.floorTraps = {}  -- {[floorPart] = trapPart}

print("[BuildService] ✓✓✓ INITIALIZED WITH NEW FORTNITE-STYLE ARCHITECTURE ✓✓✓")
print("[BuildService] - BuildGridService: READY")
print("[BuildService] - BuildSupportService: READY")
print("[BuildService] - TerrainSupportService: READY")
print("[BuildService] - BuildPlacementService: READY")
print("[BuildService] - BuildPieceFactory: READY")
print("[BuildService] - Max Build Distance:", self.config.maxBuildDistance)

return self
end

-- Validate player build distance
local function ValidateBuildDistance(player, worldPosition, maxDistance)
local character = player.Character
if not character then
return false, "Character not found"
end

local rootPart = character:FindFirstChild("HumanoidRootPart")
if not rootPart then
return false, "Character not loaded"
end

local distance = (rootPart.Position - worldPosition).Magnitude
if distance > maxDistance then
return false, string.format("Too far (%.1f studs, max %.1f)", distance, maxDistance)
end

return true, nil
end

-- Place a floor at grid position
-- worldPosition is converted to grid coordinates internally
function BuildService:PlaceFloor(player, worldPosition, rotation)
print(string.format("[BuildService] ======== PLACE FLOOR REQUEST ========"))
print(string.format("[BuildService] Player: %s", player.Name))
print(string.format("[BuildService] World Position: (%.1f, %.1f, %.1f)", worldPosition.X, worldPosition.Y, worldPosition.Z))
print(string.format("[BuildService] Rotation: %d", rotation))

-- Convert world position to grid
local x, z = self.gridService:WorldToGrid(worldPosition)
	local level = self.gridService:WorldYToLevel(worldPosition.Y)
print(string.format("[BuildService] Grid Position: (%d, %d, %d)", x, z, level))

-- Validate build distance
local gridWorldPos = self.gridService:GridToWorld(x, z, level)
local validDistance, distErr = ValidateBuildDistance(player, gridWorldPos, self.config.maxBuildDistance)
if not validDistance then
print("[BuildService] ✗ FAILED:", distErr)
return false, nil, distErr
end

-- Validate placement
local isValid, reason = self.placementService:ValidateFloorPlacement(x, z, level, rotation)
if not isValid then
print("[BuildService] ✗ FAILED:", reason)
return false, nil, reason
end

-- Create the floor
local floorPart, metadata = self.factory:CreateFloor(x, z, level, rotation)

-- Register with grid
self.gridService:RegisterFloor(x, z, level, floorPart, metadata)
print("[BuildService] ✓ Registered floor with grid service")

-- Register with support system (calculates support relationships)
self.supportService:RegisterStructure(floorPart, metadata)
print("[BuildService] ✓ Registered floor with support service")

print(string.format("[BuildService] ✓✓✓ FLOOR PLACED SUCCESSFULLY ✓✓✓"))
return true, floorPart, nil
end

-- Place a wall at grid position (determined from world position + nearest edge)
function BuildService:PlaceWall(player, worldPosition, rotation)
print(string.format("[BuildService] ======== PLACE WALL REQUEST ========"))
print(string.format("[BuildService] Player: %s", player.Name))
print(string.format("[BuildService] World Position: (%.1f, %.1f, %.1f)", worldPosition.X, worldPosition.Y, worldPosition.Z))

-- Convert world position to grid
local x, z = self.gridService:WorldToGrid(worldPosition)
	local level = self.gridService:WorldYToLevel(worldPosition.Y)
print(string.format("[BuildService] Grid Position: (%d, %d, %d)", x, z, level))

-- Determine which edge of the tile we're closest to
local edge = self.gridService:DetermineWallEdge(worldPosition, x, z)
print(string.format("[BuildService] Determined Edge: %s", edge))

-- Validate build distance
local wallWorldPos, _ = self.gridService:CalculateWallPosition(x, z, level, edge)
local validDistance, distErr = ValidateBuildDistance(player, wallWorldPos, self.config.maxBuildDistance)
if not validDistance then
print("[BuildService] ✗ FAILED:", distErr)
return false, nil, distErr
end

-- Validate placement
local isValid, reason = self.placementService:ValidateWallPlacement(x, z, level, edge)
if not isValid then
print("[BuildService] ✗ FAILED:", reason)
return false, nil, reason
end

-- Create the wall
local wallPart, metadata = self.factory:CreateWall(x, z, level, edge)

-- Register with grid
self.gridService:RegisterWall(x, z, level, edge, wallPart, metadata)
print("[BuildService] ✓ Registered wall with grid service")

-- Register with support system
self.supportService:RegisterStructure(wallPart, metadata)
print("[BuildService] ✓ Registered wall with support service")

print(string.format("[BuildService] ✓✓✓ WALL PLACED SUCCESSFULLY ✓✓✓"))
return true, wallPart, nil
end

-- Place a ramp at grid position
function BuildService:PlaceRamp(player, worldPosition, rotation)
print(string.format("[BuildService] ======== PLACE RAMP REQUEST ========"))
print(string.format("[BuildService] Player: %s", player.Name))
print(string.format("[BuildService] World Position: (%.1f, %.1f, %.1f)", worldPosition.X, worldPosition.Y, worldPosition.Z))
print(string.format("[BuildService] Rotation: %d", rotation))

-- Convert world position to grid
local x, z = self.gridService:WorldToGrid(worldPosition)
	local level = self.gridService:WorldYToLevel(worldPosition.Y)
print(string.format("[BuildService] Grid Position: (%d, %d, %d)", x, z, level))

-- Validate build distance
local gridWorldPos = self.gridService:GridToWorld(x, z, level)
local validDistance, distErr = ValidateBuildDistance(player, gridWorldPos, self.config.maxBuildDistance)
if not validDistance then
print("[BuildService] ✗ FAILED:", distErr)
return false, nil, distErr
end

-- Validate placement
local isValid, reason = self.placementService:ValidateRampPlacement(x, z, level, rotation)
if not isValid then
print("[BuildService] ✗ FAILED:", reason)
return false, nil, reason
end

-- Create the ramp
local rampPart, metadata = self.factory:CreateRamp(x, z, level, rotation)

-- Register with grid
self.gridService:RegisterRamp(x, z, level, rotation, rampPart, metadata)
print("[BuildService] ✓ Registered ramp with grid service")

-- Register with support system
self.supportService:RegisterStructure(rampPart, metadata)
print("[BuildService] ✓ Registered ramp with support service")

print(string.format("[BuildService] ✓✓✓ RAMP PLACED SUCCESSFULLY ✓✓✓"))
return true, rampPart, nil
end

-- Delete a structure (triggers cascade destruction via support service)
function BuildService:DeleteStructure(player, part)
print(string.format("[BuildService] ======== DELETE STRUCTURE REQUEST ========"))
print(string.format("[BuildService] Player: %s", player.Name))
print(string.format("[BuildService] Part: %s", part.Name))

-- Validate player is close enough
local validDistance, distErr = ValidateBuildDistance(player, part.Position, self.config.maxBuildDistance)
if not validDistance then
print("[BuildService] ✗ FAILED:", distErr)
return false, distErr
end

-- Get metadata
local metadata = self.factory:GetMetadata(part)
if not metadata then
print("[BuildService] ✗ FAILED: No metadata found (not a valid structure)")
return false, "Not a valid structure"
end

-- Unregister from support service (this triggers cascade destruction)
print("[BuildService] Unregistering from support service (will trigger cascade)...")
self.supportService:UnregisterStructure(part, metadata)

-- Unregister from grid
if metadata.pieceType == "floor" then
self.gridService:UnregisterFloor(metadata.gridX, metadata.gridZ, metadata.gridLevel)
elseif metadata.pieceType == "wall" then
self.gridService:UnregisterWall(metadata.gridX, metadata.gridZ, metadata.gridLevel, metadata.edge)
elseif metadata.pieceType == "ramp" then
self.gridService:UnregisterRamp(metadata.gridX, metadata.gridZ, metadata.gridLevel, metadata.rotation)
end
print("[BuildService] ✓ Unregistered from grid service")

-- Destroy the piece
self.factory:DestroyPiece(part, metadata)

print(string.format("[BuildService] ✓✓✓ STRUCTURE DELETED ✓✓✓"))
return true, nil
end

-- Cleanup
function BuildService:Destroy()
print("[BuildService] Cleaning up...")

-- Factory handles cleanup of all pieces
if self.factory then
self.factory:Destroy()
end

print("[BuildService] ✓ Cleanup complete")
end

return BuildService
