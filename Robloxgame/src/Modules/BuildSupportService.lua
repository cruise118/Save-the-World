--[[
	BuildSupportService.lua
	Tracks structural support relationships and handles cascade destruction
	
	Provides:
	- Support validation (can a piece be placed here?)
	- Support tracking (what supports what?)
	- Cascade destruction (if support removed, dependent structures collapse)
]]

local BuildSupportService = {}
BuildSupportService.__index = BuildSupportService

--[[
	Create a new BuildSupportService instance
	
	Dependencies:
	- gridService: BuildGridService
	- terrainService: TerrainSupportService
]]
function BuildSupportService.new(gridService, terrainService)
	assert(gridService, "BuildSupportService requires gridService")
	assert(terrainService, "BuildSupportService requires terrainService")
	
	local self = setmetatable({}, BuildSupportService)
	
	self.gridService = gridService
	self.terrainService = terrainService
	
	-- Track support relationships
	-- Key: structureId, Value: {supportedBy = {structureIds}, supports = {structureIds}}
	self.supportGraph = {}
	
	-- Structure registry
	-- Key: structureId, Value: structureData (type, x, z, level, rotation, etc.)
	self.structures = {}
	
	-- ID counter
	self.nextId = 1
	
	return self
end

--[[
	Generate unique structure ID
]]
function BuildSupportService:GenerateId(): string
	local id = "struct_" .. self.nextId
	self.nextId = self.nextId + 1
	return id
end

--[[
	Check if a floor at (x, z, level) is supported
	
	A floor is supported if:
	- Terrain supports it (level == 0)
	- OR another floor exists at the same level within 1 tile
	- OR walls exist beneath it (at level-1)
	- OR a ramp exists that would reach this level
	
	Returns: boolean, reason (string if not supported)
]]
function BuildSupportService:IsFloorSupported(x: number, z: number, level: number): (boolean, string?)
	-- Check terrain support
	if self.terrainService:HasTerrainSupport(x, z, level) then
		return true
	end
	
	-- Level 0 must be on terrain
	if level == 0 then
		return false, "Floor must be placed on terrain at ground level"
	end
	
	-- Check for floor at same level within 1 tile (connected floors)
	-- This allows expanding floors horizontally
	for dx = -1, 1 do
		for dz = -1, 1 do
			if not (dx == 0 and dz == 0) then
				if self.gridService:IsFloorOccupied(x + dx, z + dz, level) then
					return true
				end
			end
		end
	end
	
	-- Check for walls beneath (at level-1) supporting this floor
	-- A floor can be placed on top of 4 walls surrounding a tile
	local hasWallSupport = false
	local directions = {"N", "S", "E", "W"}
	
	for _, dir in ipairs(directions) do
		if self.gridService:IsWallOccupied(x, z, dir, level - 1) then
			hasWallSupport = true
			break
		end
	end
	
	if hasWallSupport then
		return true
	end
	
	-- Check for floor directly below (vertical stacking)
	if self.gridService:IsFloorOccupied(x, z, level - 1) then
		return true
	end
	
	return false, "Floor must be supported by terrain, adjacent floors, walls beneath, or floor below"
end

--[[
	Check if a wall at (x, z, direction, level) is supported
	
	A wall is supported if:
	- A floor exists at the same level adjacent to the wall edge
	- OR walls exist below it (level-1) at the same edge
	
	Returns: boolean, reason (string if not supported)
]]
function BuildSupportService:IsWallSupported(x: number, z: number, direction: string, level: number): (boolean, string?)
	-- Walls must have a floor adjacent at the same level
	-- Check the two tiles that share this edge
	
	local tile1X, tile1Z = x, z
	local tile2X, tile2Z
	
	-- Determine adjacent tile based on direction
	if direction == "N" then
		tile2X, tile2Z = x, z + 1
	elseif direction == "S" then
		tile2X, tile2Z = x, z - 1
	elseif direction == "E" then
		tile2X, tile2Z = x + 1, z
	elseif direction == "W" then
		tile2X, tile2Z = x - 1, z
	end
	
	-- Check if at least one adjacent tile has a floor
	local hasFloor1 = self.gridService:IsFloorOccupied(tile1X, tile1Z, level)
	local hasFloor2 = self.gridService:IsFloorOccupied(tile2X, tile2Z, level)
	
	if hasFloor1 or hasFloor2 then
		return true
	end
	
	-- Check for wall beneath (vertical stacking)
	if level > 0 and self.gridService:IsWallOccupied(x, z, direction, level - 1) then
		return true
	end
	
	return false, "Wall must be adjacent to a floor or stacked on a wall below"
end

--[[
	Check if a ramp at (x, z, rotation, level) is supported
	
	A ramp is supported if:
	- Terrain supports the base (level == 0)
	- OR a floor exists at the base level
	
	Returns: boolean, reason (string if not supported)
]]
function BuildSupportService:IsRampSupported(x: number, z: number, rotation: number, level: number): (boolean, string?)
	-- Check terrain support
	if self.terrainService:HasTerrainSupport(x, z, level) then
		return true
	end
	
	-- Check for floor at same level (ramp sits on floor)
	if self.gridService:IsFloorOccupied(x, z, level) then
		return true
	end
	
	return false, "Ramp must be placed on terrain or an existing floor"
end

--[[
	Register a structure and its support relationships
	
	structureData should contain:
	- type: "floor", "wall", "ramp"
	- x, z: grid coordinates
	- level: integer
	- rotation: number (for ramps/walls)
	- direction: string (for walls)
	- part: BasePart instance
	
	Returns: structureId (string)
]]
function BuildSupportService:RegisterStructure(structureData): string
	local id = self:GenerateId()
	
	-- Store structure data
	self.structures[id] = structureData
	structureData.id = id
	
	-- Initialize support graph entry
	self.supportGraph[id] = {
		supportedBy = {},  -- Structures that support this one
		supports = {}      -- Structures that this one supports
	}
	
	-- Calculate and register support relationships
	self:CalculateSupportRelationships(id)
	
	return id
end

--[[
	Calculate what supports a structure and what it supports
	Internal helper
]]
function BuildSupportService:CalculateSupportRelationships(structureId: string)
	local data = self.structures[structureId]
	if not data then
		return
	end
	
	local x, z, level = data.x, data.z, data.level
	local supportedBy = {}
	
	if data.type == "floor" then
		-- Floor can be supported by:
		-- 1. Terrain (implicit, no structure)
		-- 2. Adjacent floors at same level
		-- 3. Walls beneath
		-- 4. Floor beneath
		
		if level > 0 then
			-- Check for adjacent floors
			for dx = -1, 1 do
				for dz = -1, 1 do
					if not (dx == 0 and dz == 0) then
						local floorData = self.gridService:GetFloorAt(x + dx, z + dz, level)
						if floorData and floorData.id and floorData.id ~= structureId then
							table.insert(supportedBy, floorData.id)
						end
					end
				end
			end
			
			-- Check for walls beneath
			local directions = {"N", "S", "E", "W"}
			for _, dir in ipairs(directions) do
				local wallData = self.gridService:GetWallAt(x, z, dir, level - 1)
				if wallData and wallData.id then
					table.insert(supportedBy, wallData.id)
				end
			end
			
			-- Check for floor beneath
			local floorBelow = self.gridService:GetFloorAt(x, z, level - 1)
			if floorBelow and floorBelow.id then
				table.insert(supportedBy, floorBelow.id)
			end
		end
		
	elseif data.type == "wall" then
		-- Wall supported by:
		-- 1. Adjacent floors at same level
		-- 2. Wall beneath
		
		local tile1X, tile1Z = x, z
		local tile2X, tile2Z
		
		if data.direction == "N" then
			tile2X, tile2Z = x, z + 1
		elseif data.direction == "S" then
			tile2X, tile2Z = x, z - 1
		elseif data.direction == "E" then
			tile2X, tile2Z = x + 1, z
		elseif data.direction == "W" then
			tile2X, tile2Z = x - 1, z
		end
		
		-- Check adjacent floors
		local floor1 = self.gridService:GetFloorAt(tile1X, tile1Z, level)
		if floor1 and floor1.id then
			table.insert(supportedBy, floor1.id)
		end
		
		local floor2 = self.gridService:GetFloorAt(tile2X, tile2Z, level)
		if floor2 and floor2.id then
			table.insert(supportedBy, floor2.id)
		end
		
		-- Check wall beneath
		if level > 0 then
			local wallBelow = self.gridService:GetWallAt(x, z, data.direction, level - 1)
			if wallBelow and wallBelow.id then
				table.insert(supportedBy, wallBelow.id)
			end
		end
		
	elseif data.type == "ramp" then
		-- Ramp supported by:
		-- 1. Terrain (implicit)
		-- 2. Floor at same level
		
		if level > 0 then
			local floor = self.gridService:GetFloorAt(x, z, level)
			if floor and floor.id then
				table.insert(supportedBy, floor.id)
			end
		end
	end
	
	-- Update support graph
	self.supportGraph[structureId].supportedBy = supportedBy
	
	-- Update reverse relationships (this structure now supports those structures)
	for _, supporterId in ipairs(supportedBy) do
		if self.supportGraph[supporterId] then
			table.insert(self.supportGraph[supporterId].supports, structureId)
		end
	end
end

--[[
	Unregister a structure and handle cascade destruction
	
	Returns: affectedStructures (array of structureIds that were destroyed)
]]
function BuildSupportService:UnregisterStructure(structureId: string): {string}
	local affectedStructures = {structureId}
	
	-- Get structures that were supported by this one
	local graph = self.supportGraph[structureId]
	if not graph then
		return affectedStructures
	end
	
	local dependents = graph.supports
	
	-- Remove this structure from support graph
	self.structures[structureId] = nil
	self.supportGraph[structureId] = nil
	
	-- Remove references to this structure from other structures' support lists
	for id, g in pairs(self.supportGraph) do
		local newSupportedBy = {}
		for _, supportId in ipairs(g.supportedBy) do
			if supportId ~= structureId then
				table.insert(newSupportedBy, supportId)
			end
		end
		g.supportedBy = newSupportedBy
	end
	
	-- Check each dependent to see if it's still supported
	for _, dependentId in ipairs(dependents) do
		if self.structures[dependentId] then
			local data = self.structures[dependentId]
			local isSupported = false
			
			if data.type == "floor" then
				isSupported = self:IsFloorSupported(data.x, data.z, data.level)
			elseif data.type == "wall" then
				isSupported = self:IsWallSupported(data.x, data.z, data.direction, data.level)
			elseif data.type == "ramp" then
				isSupported = self:IsRampSupported(data.x, data.z, data.rotation, data.level)
			end
			
			-- If no longer supported, cascade destroy
			if not isSupported then
				local cascaded = self:UnregisterStructure(dependentId)
				for _, id in ipairs(cascaded) do
					table.insert(affectedStructures, id)
				end
			end
		end
	end
	
	return affectedStructures
end

--[[
	Get structure data by ID
	Returns: structureData or nil
]]
function BuildSupportService:GetStructure(structureId: string)
	return self.structures[structureId]
end

--[[
	Get all structures at a specific level
	Returns: array of structureData
]]
function BuildSupportService:GetStructuresAtLevel(level: number): {any}
	local structures = {}
	for _, data in pairs(self.structures) do
		if data.level == level then
			table.insert(structures, data)
		end
	end
	return structures
end

--[[
	Cleanup
]]
function BuildSupportService:Destroy()
	self.supportGraph = {}
	self.structures = {}
	self.gridService = nil
	self.terrainService = nil
end

return BuildSupportService
