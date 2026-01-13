--[[
	BuildSupportService.lua
	Manages support validation, dependency tracking, and cascade destruction
]]

local BuildConfig = require(script.Parent.BuildConfig)

local BuildSupportService = {}
BuildSupportService.__index = BuildSupportService

-- Constructor
function BuildSupportService.new(buildGridService, buildPieceFactory)
	local self = setmetatable({}, BuildSupportService)
	
	self._gridService = buildGridService
	self._factory = buildPieceFactory
	
	-- Dependency graph: structureId -> {supportedBy = {ids}, supporting = {ids}}
	self._dependencies = {}
	
	return self
end

-- Check if a structure has valid support
function BuildSupportService:HasValidSupport(gridX, gridZ, level, structureType)
	-- Check terrain support (level 0 / ground level)
	if self._gridService:HasTerrainSupport(gridX, gridZ, level) then
		return true, "terrain"
	end
	
	-- Check for support from structures below
	if level > 0 then
		local supportFound = false
		local supportType = nil
		
		-- Check for floor directly below
		local floorBelow = self._gridService:GetStructureAt(gridX, gridZ, level - 1, BuildConfig.StructureType.Floor)
		if floorBelow and self._factory:CanSupportAbove(BuildConfig.StructureType.Floor) then
			supportFound = true
			supportType = "floor_below"
		end
		
		-- Check for wall directly below (walls can support structures above)
		if not supportFound then
			local wallBelow = self._gridService:GetStructureAt(gridX, gridZ, level - 1, BuildConfig.StructureType.Wall)
			if wallBelow and self._factory:CanSupportAbove(BuildConfig.StructureType.Wall) then
				supportFound = true
				supportType = "wall_below"
			end
		end
		
		-- For walls specifically, check if there's a floor at the same level (walls can be placed on floor edges)
		if not supportFound and structureType == BuildConfig.StructureType.Wall then
			local floorSameLevel = self._gridService:GetStructureAt(gridX, gridZ, level, BuildConfig.StructureType.Floor)
			if floorSameLevel then
				supportFound = true
				supportType = "floor_same_level"
			end
		end
		
		return supportFound, supportType
	end
	
	return false, nil
end

-- Register structure in dependency graph
function BuildSupportService:RegisterStructure(metadata)
	if not metadata or not metadata.Id then
		error("Invalid metadata provided to RegisterStructure")
	end
	
	self._dependencies[metadata.Id] = {
		metadata = metadata,
		supportedBy = {},
		supporting = {}
	}
	
	-- Find and register support dependencies
	self:_updateDependencies(metadata)
end

-- Update dependencies for a structure
function BuildSupportService:_updateDependencies(metadata)
	local gridX, gridZ, level = metadata.GridX, metadata.GridZ, metadata.Level
	local structureType = metadata.Type
	
	-- Find what supports this structure
	if level == 0 then
		-- Supported by terrain
		if self._gridService:HasTerrainSupport(gridX, gridZ, level) then
			self._dependencies[metadata.Id].supportedBy = {"terrain"}
		end
	else
		local supporters = {}
		
		-- Check floor below
		local floorBelow = self._gridService:GetStructureAt(gridX, gridZ, level - 1, BuildConfig.StructureType.Floor)
		if floorBelow then
			table.insert(supporters, floorBelow.Id)
			-- Register this structure as being supported by floor below
			if self._dependencies[floorBelow.Id] then
				table.insert(self._dependencies[floorBelow.Id].supporting, metadata.Id)
			end
		end
		
		-- Check wall below
		local wallBelow = self._gridService:GetStructureAt(gridX, gridZ, level - 1, BuildConfig.StructureType.Wall)
		if wallBelow then
			table.insert(supporters, wallBelow.Id)
			if self._dependencies[wallBelow.Id] then
				table.insert(self._dependencies[wallBelow.Id].supporting, metadata.Id)
			end
		end
		
		-- For walls on same level floor
		if structureType == BuildConfig.StructureType.Wall then
			local floorSameLevel = self._gridService:GetStructureAt(gridX, gridZ, level, BuildConfig.StructureType.Floor)
			if floorSameLevel then
				table.insert(supporters, floorSameLevel.Id)
				if self._dependencies[floorSameLevel.Id] then
					table.insert(self._dependencies[floorSameLevel.Id].supporting, metadata.Id)
				end
			end
		end
		
		self._dependencies[metadata.Id].supportedBy = supporters
	end
end

-- Unregister structure from dependency graph
function BuildSupportService:UnregisterStructure(structureId)
	local depData = self._dependencies[structureId]
	if not depData then
		return {}
	end
	
	-- Remove this structure from supporters' lists
	for _, supporterId in ipairs(depData.supportedBy) do
		if self._dependencies[supporterId] then
			local supporting = self._dependencies[supporterId].supporting
			for i, id in ipairs(supporting) do
				if id == structureId then
					table.remove(supporting, i)
					break
				end
			end
		end
	end
	
	-- Get list of structures that were being supported by this one
	local affectedStructures = depData.supporting or {}
	
	-- Remove from dependency graph
	self._dependencies[structureId] = nil
	
	return affectedStructures
end

-- Calculate cascade destruction (BFS to find all unsupported structures)
function BuildSupportService:CalculateCascadeDestruction(removedStructureId)
	local toDestroy = {}
	local checked = {}
	
	-- Get structures that were supported by the removed structure
	local affectedStructures = self:UnregisterStructure(removedStructureId)
	
	-- Queue for BFS
	local queue = {}
	for _, structureId in ipairs(affectedStructures) do
		table.insert(queue, structureId)
	end
	
	-- BFS to find all unsupported structures
	while #queue > 0 do
		local currentId = table.remove(queue, 1)
		
		if not checked[currentId] and self._dependencies[currentId] then
			checked[currentId] = true
			
			local depData = self._dependencies[currentId]
			local hasSupport = false
			
			-- Check if structure still has support
			for _, supporterId in ipairs(depData.supportedBy) do
				if supporterId == "terrain" or (self._dependencies[supporterId] and not toDestroy[supporterId]) then
					hasSupport = true
					break
				end
			end
			
			-- If no support, mark for destruction and check dependents
			if not hasSupport then
				toDestroy[currentId] = true
				
				-- Add structures supported by this one to queue
				for _, supportedId in ipairs(depData.supporting) do
					if not checked[supportedId] then
						table.insert(queue, supportedId)
					end
				end
			end
		end
	end
	
	-- Convert to array
	local destructionList = {}
	for structureId, _ in pairs(toDestroy) do
		table.insert(destructionList, structureId)
		self:UnregisterStructure(structureId)
	end
	
	return destructionList
end

-- Get dependency info for debugging
function BuildSupportService:GetDependencyInfo(structureId)
	return self._dependencies[structureId]
end

-- Clear all dependencies
function BuildSupportService:Clear()
	self._dependencies = {}
end

return BuildSupportService
