--[[
	BuildGridService
	Foundational grid + occupancy data model for building system
	
	Handles:
	- Grid coordinate conversion
	- Occupancy tracking (floors, walls, ramps)
	- Structure data storage
]]

local BuildGridService = {}
BuildGridService.__index = BuildGridService

-- Constants
local TILE_SIZE = 12 -- studs
local LEVEL_HEIGHT = 8 -- studs (equals wallHeight)

-- Piece types
local PieceTypes = {
	Floor = "Floor",
	Wall = "Wall",
	Ramp = "Ramp"
}

function BuildGridService.new()
	local self = setmetatable({}, BuildGridService)
	
	-- Occupancy storage
	self.floors = {} -- [x][z][level] = structureRecord
	self.walls = {} -- [x][z][level][dir] = structureRecord
	self.ramps = {} -- [x][z][level][rot] = structureRecord
	
	-- Structure lookup by ID
	self.structures = {} -- [id] = structureRecord
	
	-- ID counter
	self.nextId = 1
	
	return self
end

-- Coordinate conversion helpers
function BuildGridService:WorldToGrid(worldPos)
	local x = math.floor(worldPos.X / TILE_SIZE + 0.5)
	local z = math.floor(worldPos.Z / TILE_SIZE + 0.5)
	local level = math.floor(worldPos.Y / LEVEL_HEIGHT + 0.5)
	return x, z, level
end

function BuildGridService:GridToWorld(x, z, level)
	local worldX = x * TILE_SIZE
	local worldY = level * LEVEL_HEIGHT + 0.5 -- 0.5 offset to sit on surface
	local worldZ = z * TILE_SIZE
	return Vector3.new(worldX, worldY, worldZ)
end

-- Occupancy checking
function BuildGridService:CanPlaceFloor(x, z, level)
	if not self.floors[x] then return true end
	if not self.floors[x][z] then return true end
	if not self.floors[x][z][level] then return true end
	return false -- slot occupied
end

function BuildGridService:CanPlaceWall(x, z, level, dir)
	-- dir must be "N", "E", "S", or "W"
	if dir ~= "N" and dir ~= "E" and dir ~= "S" and dir ~= "W" then
		return false
	end
	
	if not self.walls[x] then return true end
	if not self.walls[x][z] then return true end
	if not self.walls[x][z][level] then return true end
	if not self.walls[x][z][level][dir] then return true end
	return false -- slot occupied
end

function BuildGridService:CanPlaceRamp(x, z, level, rot)
	-- rot must be 0, 90, 180, or 270
	if rot ~= 0 and rot ~= 90 and rot ~= 180 and rot ~= 270 then
		return false
	end
	
	if not self.ramps[x] then return true end
	if not self.ramps[x][z] then return true end
	if not self.ramps[x][z][level] then return true end
	if not self.ramps[x][z][level][rot] then return true end
	return false -- slot occupied
end

-- Structure management
function BuildGridService:AddStructure(record)
	-- Validate required fields
	assert(record.type, "Structure record must have 'type' field")
	assert(record.x, "Structure record must have 'x' field")
	assert(record.z, "Structure record must have 'z' field")
	assert(record.level, "Structure record must have 'level' field")
	
	-- Generate ID if not provided
	if not record.id then
		record.id = "struct_" .. self.nextId
		self.nextId = self.nextId + 1
	end
	
	-- Set defaults
	if not record.maxHP then record.maxHP = 100 end
	if not record.hp then record.hp = record.maxHP end
	if not record.tier then record.tier = "MVP" end
	
	local x, z, level = record.x, record.z, record.level
	
	-- Store in appropriate occupancy table
	if record.type == PieceTypes.Floor then
		-- Ensure nested tables exist
		if not self.floors[x] then self.floors[x] = {} end
		if not self.floors[x][z] then self.floors[x][z] = {} end
		self.floors[x][z][level] = record
		
	elseif record.type == PieceTypes.Wall then
		assert(record.dir, "Wall record must have 'dir' field")
		local dir = record.dir
		
		-- Ensure nested tables exist
		if not self.walls[x] then self.walls[x] = {} end
		if not self.walls[x][z] then self.walls[x][z] = {} end
		if not self.walls[x][z][level] then self.walls[x][z][level] = {} end
		self.walls[x][z][level][dir] = record
		
	elseif record.type == PieceTypes.Ramp then
		assert(record.rot, "Ramp record must have 'rot' field")
		local rot = record.rot
		
		-- Ensure nested tables exist
		if not self.ramps[x] then self.ramps[x] = {} end
		if not self.ramps[x][z] then self.ramps[x][z] = {} end
		if not self.ramps[x][z][level] then self.ramps[x][z][level] = {} end
		self.ramps[x][z][level][rot] = record
		
	else
		error("Unknown structure type: " .. tostring(record.type))
	end
	
	-- Store in ID lookup
	self.structures[record.id] = record
	
	return record
end

function BuildGridService:RemoveStructure(id)
	local record = self.structures[id]
	if not record then return false end
	
	local x, z, level = record.x, record.z, record.level
	
	-- Remove from appropriate occupancy table
	if record.type == PieceTypes.Floor then
		if self.floors[x] and self.floors[x][z] then
			self.floors[x][z][level] = nil
		end
		
	elseif record.type == PieceTypes.Wall then
		local dir = record.dir
		if self.walls[x] and self.walls[x][z] and self.walls[x][z][level] then
			self.walls[x][z][level][dir] = nil
		end
		
	elseif record.type == PieceTypes.Ramp then
		local rot = record.rot
		if self.ramps[x] and self.ramps[x][z] and self.ramps[x][z][level] then
			self.ramps[x][z][level][rot] = nil
		end
	end
	
	-- Remove from ID lookup
	self.structures[id] = nil
	
	return true
end

-- Structure retrieval
function BuildGridService:GetStructureAtFloor(x, z, level)
	if not self.floors[x] then return nil end
	if not self.floors[x][z] then return nil end
	return self.floors[x][z][level]
end

function BuildGridService:GetStructureAtWall(x, z, level, dir)
	if not self.walls[x] then return nil end
	if not self.walls[x][z] then return nil end
	if not self.walls[x][z][level] then return nil end
	return self.walls[x][z][level][dir]
end

function BuildGridService:GetStructureAtRamp(x, z, level, rot)
	if not self.ramps[x] then return nil end
	if not self.ramps[x][z] then return nil end
	if not self.ramps[x][z][level] then return nil end
	return self.ramps[x][z][level][rot]
end

-- Getters for constants
function BuildGridService:GetTileSize()
	return TILE_SIZE
end

function BuildGridService:GetLevelHeight()
	return LEVEL_HEIGHT
end

return BuildGridService
