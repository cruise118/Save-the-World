--[[
	BuildGridService.lua
	Handles grid-based world representation for the building system
	
	Provides:
	- Grid coordinate conversion (world ↔ grid)
	- Tile/edge occupancy tracking
	- Level management
	- Rotation handling (0/90/180/270 only)
]]

local BuildGridService = {}
BuildGridService.__index = BuildGridService

-- Constants
local TILE_SIZE = 12  -- Studs per tile
local WALL_HEIGHT = 8  -- Studs per level
local LEVEL_HEIGHT = WALL_HEIGHT  -- Levels are based on wall height

--[[
	Create a new BuildGridService instance
]]
function BuildGridService.new()
	local self = setmetatable({}, BuildGridService)
	
	-- Track occupancy
	-- floorOccupancy[level][gridKey] = structureData
	-- wallOccupancy[level][edgeKey] = structureData
	-- rampOccupancy[level][gridKey_rotation] = structureData
	self.floorOccupancy = {}  -- {[level] = {[gridKey] = data}}
	self.wallOccupancy = {}   -- {[level] = {[edgeKey] = data}}
	self.rampOccupancy = {}   -- {[level] = {[gridKey_rotation] = data}}
	
	return self
end

--[[
	Convert world position to grid coordinates
	Returns: x, z (integer grid coordinates)
]]
function BuildGridService:WorldToGrid(position: Vector3): (number, number)
	local x = math.floor((position.X / TILE_SIZE) + 0.5)
	local z = math.floor((position.Z / TILE_SIZE) + 0.5)
	return x, z
end

--[[
	Convert grid coordinates to world position at specified level
	Returns: Vector3 (world position at tile center, appropriate Y for level)
]]
function BuildGridService:GridToWorld(x: number, z: number, level: number): Vector3
	local worldX = x * TILE_SIZE
	local worldZ = z * TILE_SIZE
	local worldY = level * LEVEL_HEIGHT + 0.5  -- Floor sits at level * height + 0.5
	return Vector3.new(worldX, worldY, worldZ)
end

--[[
	Get level from world Y position
	Returns: level (integer)
]]
function BuildGridService:WorldYToLevel(worldY: number): number
	return math.floor((worldY / LEVEL_HEIGHT) + 0.5)
end

--[[
	Snap rotation to valid values (0, 90, 180, 270)
	Returns: rotation (number)
]]
function BuildGridService:SnapRotation(rotation: number): number
	local snapped = math.floor((rotation / 90) + 0.5) * 90
	return snapped % 360
end

--[[
	Get grid key from coordinates
	Returns: gridKey (string)
]]
function BuildGridService:GetGridKey(x: number, z: number): string
	return string.format("%d_%d", x, z)
end

--[[
	Get edge key from coordinates and direction
	direction: "N", "S", "E", "W"
	Returns: edgeKey (string)
]]
function BuildGridService:GetEdgeKey(x: number, z: number, direction: string): string
	return string.format("%d_%d_%s", x, z, direction)
end

--[[
	Get ramp key from coordinates and rotation
	Returns: rampKey (string)
]]
function BuildGridService:GetRampKey(x: number, z: number, rotation: number): string
	local snappedRot = self:SnapRotation(rotation)
	return string.format("%d_%d_R%d", x, z, snappedRot)
end

--[[
	Calculate wall edge position in world space
	Walls sit on tile edges, not inside tiles
	Returns: worldPosition (Vector3), orientation (Vector3)
]]
function BuildGridService:CalculateWallPosition(x: number, z: number, direction: string, level: number): (Vector3, Vector3)
	local tileCenter = self:GridToWorld(x, z, level)
	local halfTile = TILE_SIZE / 2
	local wallY = level * LEVEL_HEIGHT + WALL_HEIGHT / 2 + 0.5
	
	local position, orientation
	
	if direction == "N" then
		-- North edge (+Z)
		position = Vector3.new(tileCenter.X, wallY, tileCenter.Z + halfTile)
		orientation = Vector3.new(0, 0, 0)
	elseif direction == "S" then
		-- South edge (-Z)
		position = Vector3.new(tileCenter.X, wallY, tileCenter.Z - halfTile)
		orientation = Vector3.new(0, 0, 0)
	elseif direction == "E" then
		-- East edge (+X)
		position = Vector3.new(tileCenter.X + halfTile, wallY, tileCenter.Z)
		orientation = Vector3.new(0, 90, 0)
	elseif direction == "W" then
		-- West edge (-X)
		position = Vector3.new(tileCenter.X - halfTile, wallY, tileCenter.Z)
		orientation = Vector3.new(0, 90, 0)
	else
		error("Invalid wall direction: " .. tostring(direction))
	end
	
	return position, orientation
end

--[[
	Determine nearest wall edge from a world position relative to a tile
	Returns: direction ("N", "S", "E", "W")
]]
function BuildGridService:DetermineWallEdge(tileX: number, tileZ: number, worldPos: Vector3): string
	local tileCenter = self:GridToWorld(tileX, tileZ, 0)  -- Level doesn't matter for X/Z
	local relativePos = worldPos - tileCenter
	
	-- Determine edge based on which component is larger
	if math.abs(relativePos.X) > math.abs(relativePos.Z) then
		return relativePos.X > 0 and "E" or "W"
	else
		return relativePos.Z > 0 and "N" or "S"
	end
end

--[[
	Check if a floor tile is occupied
	Returns: boolean
]]
function BuildGridService:IsFloorOccupied(x: number, z: number, level: number): boolean
	if not self.floorOccupancy[level] then
		return false
	end
	
	local gridKey = self:GetGridKey(x, z)
	return self.floorOccupancy[level][gridKey] ~= nil
end

--[[
	Check if a wall edge is occupied
	Returns: boolean
]]
function BuildGridService:IsWallOccupied(x: number, z: number, direction: string, level: number): boolean
	if not self.wallOccupancy[level] then
		return false
	end
	
	local edgeKey = self:GetEdgeKey(x, z, direction)
	return self.wallOccupancy[level][edgeKey] ~= nil
end

--[[
	Check if a ramp position/rotation is occupied
	Returns: boolean
]]
function BuildGridService:IsRampOccupied(x: number, z: number, rotation: number, level: number): boolean
	if not self.rampOccupancy[level] then
		return false
	end
	
	local rampKey = self:GetRampKey(x, z, rotation)
	return self.rampOccupancy[level][rampKey] ~= nil
end

--[[
	Register a floor at grid position
]]
function BuildGridService:RegisterFloor(x: number, z: number, level: number, structureData)
	if not self.floorOccupancy[level] then
		self.floorOccupancy[level] = {}
	end
	
	local gridKey = self:GetGridKey(x, z)
	self.floorOccupancy[level][gridKey] = structureData
end

--[[
	Register a wall at edge position
]]
function BuildGridService:RegisterWall(x: number, z: number, direction: string, level: number, structureData)
	if not self.wallOccupancy[level] then
		self.wallOccupancy[level] = {}
	end
	
	local edgeKey = self:GetEdgeKey(x, z, direction)
	self.wallOccupancy[level][edgeKey] = structureData
end

--[[
	Register a ramp at grid position with rotation
]]
function BuildGridService:RegisterRamp(x: number, z: number, rotation: number, level: number, structureData)
	if not self.rampOccupancy[level] then
		self.rampOccupancy[level] = {}
	end
	
	local rampKey = self:GetRampKey(x, z, rotation)
	self.rampOccupancy[level][rampKey] = structureData
end

--[[
	Unregister a floor
]]
function BuildGridService:UnregisterFloor(x: number, z: number, level: number)
	if not self.floorOccupancy[level] then
		return
	end
	
	local gridKey = self:GetGridKey(x, z)
	self.floorOccupancy[level][gridKey] = nil
end

--[[
	Unregister a wall
]]
function BuildGridService:UnregisterWall(x: number, z: number, direction: string, level: number)
	if not self.wallOccupancy[level] then
		return
	end
	
	local edgeKey = self:GetEdgeKey(x, z, direction)
	self.wallOccupancy[level][edgeKey] = nil
end

--[[
	Unregister a ramp
]]
function BuildGridService:UnregisterRamp(x: number, z: number, rotation: number, level: number)
	if not self.rampOccupancy[level] then
		return
	end
	
	local rampKey = self:GetRampKey(x, z, rotation)
	self.rampOccupancy[level][rampKey] = nil
end

--[[
	Get floor data at position
	Returns: structureData or nil
]]
function BuildGridService:GetFloorAt(x: number, z: number, level: number)
	if not self.floorOccupancy[level] then
		return nil
	end
	
	local gridKey = self:GetGridKey(x, z)
	return self.floorOccupancy[level][gridKey]
end

--[[
	Get wall data at edge
	Returns: structureData or nil
]]
function BuildGridService:GetWallAt(x: number, z: number, direction: string, level: number)
	if not self.wallOccupancy[level] then
		return nil
	end
	
	local edgeKey = self:GetEdgeKey(x, z, direction)
	return self.wallOccupancy[level][edgeKey]
end

--[[
	Get ramp data at position
	Returns: structureData or nil
]]
function BuildGridService:GetRampAt(x: number, z: number, rotation: number, level: number)
	if not self.rampOccupancy[level] then
		return nil
	end
	
	local rampKey = self:GetRampKey(x, z, rotation)
	return self.rampOccupancy[level][rampKey]
end

--[[
	Cleanup
]]
function BuildGridService:Destroy()
	self.floorOccupancy = {}
	self.wallOccupancy = {}
	self.rampOccupancy = {}
end

return BuildGridService
