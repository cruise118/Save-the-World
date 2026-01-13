--[[
	BuildPlacementService.lua
	Validates placement, performs support checks, provides preview validation
	
	Usage:
		local BuildPlacementService = require(...BuildPlacementService)
		local service = BuildPlacementService.new(gridService, supportService, terrainService)
		
		local isValid, reason = service:ValidateFloorPlacement(x, z, level)
		local ghostColor = service:GetGhostColor(isValid)
--]]

local BuildPlacementService = {}
BuildPlacementService.__index = BuildPlacementService

-- Create new BuildPlacementService
function BuildPlacementService.new(buildGridService, buildSupportService, terrainSupportService)
	local self = setmetatable({}, BuildPlacementService)
	
	self.gridService = buildGridService
	self.supportService = buildSupportService
	self.terrainService = terrainSupportService
	
	print("[BuildPlacementService] Initialized")
	
	return self
end

-- Validate floor placement at grid position
-- Returns: (isValid: boolean, reason: string?)
function BuildPlacementService:ValidateFloorPlacement(x, z, level, rotation)
	print(string.format("[BuildPlacementService] Validating Floor at (%d, %d, %d) rotation=%d", x, z, level, rotation))
	
	-- Check if already occupied
	if self.gridService:IsFloorOccupied(x, z, level) then
		print("[BuildPlacementService] INVALID: Floor already occupied")
		return false, "Floor already exists at this location"
	end
	
	-- Check structural support
	if not self.supportService:IsFloorSupported(x, z, level) then
		print("[BuildPlacementService] INVALID: Floor not supported")
		return false, "Floor not supported (needs terrain, adjacent floor, wall beneath, or floor beneath)"
	end
	
	print("[BuildPlacementService] VALID: Floor can be placed")
	return true, nil
end

-- Validate wall placement at grid position
-- Returns: (isValid: boolean, reason: string?)
function BuildPlacementService:ValidateWallPlacement(x, z, level, edge)
	print(string.format("[BuildPlacementService] Validating Wall at (%d, %d, %d) edge=%s", x, z, level, edge))
	
	-- Check if already occupied
	if self.gridService:IsWallOccupied(x, z, level, edge) then
		print("[BuildPlacementService] INVALID: Wall already occupied")
		return false, "Wall already exists at this location"
	end
	
	-- Check structural support
	if not self.supportService:IsWallSupported(x, z, level, edge) then
		print("[BuildPlacementService] INVALID: Wall not supported")
		return false, "Wall not supported (needs adjacent floor or wall beneath)"
	end
	
	print("[BuildPlacementService] VALID: Wall can be placed")
	return true, nil
end

-- Validate ramp placement at grid position
-- Returns: (isValid: boolean, reason: string?)
function BuildPlacementService:ValidateRampPlacement(x, z, level, rotation)
	print(string.format("[BuildPlacementService] Validating Ramp at (%d, %d, %d) rotation=%d", x, z, level, rotation))
	
	-- Check if already occupied
	if self.gridService:IsRampOccupied(x, z, level, rotation) then
		print("[BuildPlacementService] INVALID: Ramp already occupied")
		return false, "Ramp already exists at this location with this rotation"
	end
	
	-- Check structural support
	if not self.supportService:IsRampSupported(x, z, level, rotation) then
		print("[BuildPlacementService] INVALID: Ramp not supported")
		return false, "Ramp not supported (needs terrain at level 0 or floor at this level)"
	end
	
	print("[BuildPlacementService] VALID: Ramp can be placed")
	return true, nil
end

-- Get ghost preview color based on validity
function BuildPlacementService:GetGhostColor(isValid)
	if isValid then
		return Color3.fromRGB(100, 255, 100)  -- Green for valid
	else
		return Color3.fromRGB(255, 100, 100)  -- Red for invalid
	end
end

return BuildPlacementService
