--[[
	TerrainSupportService.lua
	Provides terrain support queries for the building system
	
	MVP Implementation:
	- Terrain provides solid support at level = 0 for any (x, z)
	- No support at any other level
	
	This abstraction allows real terrain to be added later without
	refactoring the building code.
]]

local TerrainSupportService = {}
TerrainSupportService.__index = TerrainSupportService

--[[
	Create a new TerrainSupportService instance
]]
function TerrainSupportService.new()
	local self = setmetatable({}, TerrainSupportService)
	return self
end

--[[
	Check if terrain provides support at the specified grid position and level
	
	MVP: Returns true only if level == 0
	
	Returns: boolean (true if terrain supports at this location)
]]
function TerrainSupportService:HasTerrainSupport(x: number, z: number, level: number): boolean
	-- MVP: Terrain only provides support at level 0 (ground level)
	return level == 0
end

--[[
	Get terrain height at grid position (in levels)
	
	MVP: Always returns 0 (flat terrain at level 0)
	
	Returns: level (integer)
]]
function TerrainSupportService:GetTerrainLevel(x: number, z: number): number
	-- MVP: Flat terrain everywhere at level 0
	return 0
end

--[[
	Check if position is within valid build bounds
	
	MVP: No bounds checking, always returns true
	Future: Could implement build zone restrictions
	
	Returns: boolean
]]
function TerrainSupportService:IsWithinBuildBounds(x: number, z: number): boolean
	-- MVP: No bounds checking
	return true
end

--[[
	Cleanup (no resources to clean up in MVP)
]]
function TerrainSupportService:Destroy()
	-- Nothing to clean up
end

return TerrainSupportService
