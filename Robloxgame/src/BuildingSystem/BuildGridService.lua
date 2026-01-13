--[[
	BuildGridService.lua
	Manages the discrete tile grid, coordinate validation, and tile occupancy tracking
]]

local BuildConfig = require(script.Parent.BuildConfig)

local BuildGridService = {}
BuildGridService.__index = BuildGridService

-- Constructor
function BuildGridService.new()
	local self = setmetatable({}, BuildGridService)
	
	-- Grid state: tracks occupied tiles
	-- Key format: "x,z,level,structureType" -> structureMetadata
	self._grid = {}
	
	-- Terrain support tracking (MVP: hardcoded terrain level support)
	self._terrainSupportLevel = 0 -- Ground level
	
	return self
end

-- Snap coordinates to grid
function BuildGridService:SnapToGrid(x, z)
	local tileSize = BuildConfig.TileSize
	return math.floor(x / tileSize + 0.5) * tileSize, math.floor(z / tileSize + 0.5) * tileSize
end

-- Convert world position to grid coordinates
function BuildGridService:WorldToGrid(worldX, worldZ)
	local tileSize = BuildConfig.TileSize
	return math.floor(worldX / tileSize + 0.5), math.floor(worldZ / tileSize + 0.5)
end

-- Convert grid coordinates to world position
function BuildGridService:GridToWorld(gridX, gridZ, level)
	level = level or 0
	local worldX = gridX * BuildConfig.TileSize
	local worldZ = gridZ * BuildConfig.TileSize
	local worldY = level * BuildConfig.LevelHeight
	return worldX, worldY, worldZ
end

-- Validate rotation angle
function BuildGridService:IsValidRotation(rotation)
	for _, validRotation in ipairs(BuildConfig.AllowedRotations) do
		if rotation == validRotation then
			return true
		end
	end
	return false
end

-- Generate grid key for tile occupancy tracking
function BuildGridService:_generateKey(gridX, gridZ, level, structureType)
	return string.format("%d,%d,%d,%s", gridX, gridZ, level, structureType)
end

-- Check if a tile position is occupied
function BuildGridService:IsTileOccupied(gridX, gridZ, level, structureType)
	local key = self:_generateKey(gridX, gridZ, level, structureType)
	return self._grid[key] ~= nil
end

-- Check for wall on edge between two tiles
function BuildGridService:IsWallOnEdge(gridX, gridZ, level, direction)
	-- Direction: "North", "South", "East", "West"
	-- Walls are stored at the tile they're adjacent to with specific direction
	local key = self:_generateKey(gridX, gridZ, level, BuildConfig.StructureType.Wall .. "_" .. direction)
	return self._grid[key] ~= nil
end

-- Mark tile as occupied
function BuildGridService:OccupyTile(gridX, gridZ, level, structureType, metadata)
	local key = self:_generateKey(gridX, gridZ, level, structureType)
	self._grid[key] = metadata
	return key
end

-- Remove structure from grid
function BuildGridService:RemoveStructure(gridX, gridZ, level, structureType)
	local key = self:_generateKey(gridX, gridZ, level, structureType)
	local metadata = self._grid[key]
	self._grid[key] = nil
	return metadata
end

-- Get structure metadata at position
function BuildGridService:GetStructureAt(gridX, gridZ, level, structureType)
	local key = self:_generateKey(gridX, gridZ, level, structureType)
	return self._grid[key]
end

-- Check if position has terrain support (MVP: simplified logic)
function BuildGridService:HasTerrainSupport(gridX, gridZ, level)
	-- MVP: Terrain provides support at level 0 (ground level)
	return level == self._terrainSupportLevel
end

-- Get all structures (for debugging/iteration)
function BuildGridService:GetAllStructures()
	local structures = {}
	for key, metadata in pairs(self._grid) do
		table.insert(structures, {
			key = key,
			metadata = metadata
		})
	end
	return structures
end

-- Clear all structures from grid
function BuildGridService:Clear()
	self._grid = {}
end

return BuildGridService
