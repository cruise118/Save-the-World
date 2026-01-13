--[[
	BuildPlacementService - Phase 2: Validation Layer
	
	Provides validation logic for build placement.
	Checks bounds, overlap, and basic sanity.
	Support validation is a placeholder for now (always returns true).
	
	NO VISUALS, NO UI - Pure validation logic only.
]]

local BuildPlacementService = {}

-- Configuration
local CONFIG = {
	-- Grid bounds (nil = unbounded for now)
	minX = nil, -- TODO: Set actual bounds when world size is determined
	maxX = nil,
	minZ = nil,
	maxZ = nil,
	minLevel = 0,
	maxLevel = 10, -- Reasonable default
}

-- Valid directions and rotations
local VALID_DIRECTIONS = {N = true, E = true, S = true, W = true}
local VALID_ROTATIONS = {[0] = true, [90] = true, [180] = true, [270] = true}

-- Dependency
local BuildGridService

function BuildPlacementService.Init(buildGridService)
	BuildGridService = buildGridService
	print("[BuildPlacementService] Initialized")
end

-- Helper: Check if position is within bounds
local function CheckBounds(x, z, level)
	if CONFIG.minX and x < CONFIG.minX then
		return false, string.format("X coordinate %d below minimum %d", x, CONFIG.minX)
	end
	if CONFIG.maxX and x > CONFIG.maxX then
		return false, string.format("X coordinate %d above maximum %d", x, CONFIG.maxX)
	end
	if CONFIG.minZ and z < CONFIG.minZ then
		return false, string.format("Z coordinate %d below minimum %d", z, CONFIG.minZ)
	end
	if CONFIG.maxZ and z > CONFIG.maxZ then
		return false, string.format("Z coordinate %d above maximum %d", z, CONFIG.maxZ)
	end
	if level < CONFIG.minLevel then
		return false, string.format("Level %d below minimum %d", level, CONFIG.minLevel)
	end
	if level > CONFIG.maxLevel then
		return false, string.format("Level %d above maximum %d", level, CONFIG.maxLevel)
	end
	return true, ""
end

--[[
	ValidateSupport - Placeholder for structural support validation
	
	This will be implemented in Phase 3 with TerrainSupportService and BuildSupportService.
	For now, always returns true.
	
	@param pieceType: "Floor" | "Wall" | "Ramp"
	@param x: grid X coordinate
	@param z: grid Z coordinate  
	@param level: vertical level
	@param dirOrRot: direction string for walls, rotation number for ramps, nil for floors
	@return ok: boolean
	@return reason: string (empty if ok)
]]
function BuildPlacementService.ValidateSupport(pieceType, x, z, level, dirOrRot)
	-- TODO: Implement structural support validation in Phase 3
	-- Will check:
	-- - Terrain support at level 0
	-- - Floor support from structures below
	-- - Wall support requirements
	-- - Ramp support requirements
	return true, ""
end

--[[
	ValidateFloor - Validate floor placement
	
	@param x: grid X coordinate
	@param z: grid Z coordinate
	@param level: vertical level
	@return ok: boolean - true if placement is valid
	@return reason: string - explanation if invalid, empty if valid
]]
function BuildPlacementService.ValidateFloor(x, z, level)
	assert(BuildGridService, "BuildPlacementService not initialized")
	
	-- Check bounds
	local boundsOk, boundsReason = CheckBounds(x, z, level)
	if not boundsOk then
		return false, "Floor placement out of bounds: " .. boundsReason
	end
	
	-- Check if already occupied
	if not BuildGridService:CanPlaceFloor(x, z, level) then
		return false, string.format("Floor slot already occupied at (%d, %d, %d)", x, z, level)
	end
	
	-- Check structural support (placeholder)
	local supportOk, supportReason = BuildPlacementService.ValidateSupport("Floor", x, z, level, nil)
	if not supportOk then
		return false, "Floor not supported: " .. supportReason
	end
	
	return true, ""
end

--[[
	ValidateWall - Validate wall placement
	
	@param x: grid X coordinate
	@param z: grid Z coordinate
	@param level: vertical level
	@param dir: direction string ("N", "E", "S", "W")
	@return ok: boolean - true if placement is valid
	@return reason: string - explanation if invalid, empty if valid
]]
function BuildPlacementService.ValidateWall(x, z, level, dir)
	assert(BuildGridService, "BuildPlacementService not initialized")
	
	-- Sanity check: valid direction
	if type(dir) ~= "string" then
		return false, string.format("Wall direction must be string, got %s", type(dir))
	end
	if not VALID_DIRECTIONS[dir] then
		return false, string.format("Wall direction '%s' is invalid, must be N/E/S/W", tostring(dir))
	end
	
	-- Check bounds
	local boundsOk, boundsReason = CheckBounds(x, z, level)
	if not boundsOk then
		return false, "Wall placement out of bounds: " .. boundsReason
	end
	
	-- Check if already occupied
	if not BuildGridService:CanPlaceWall(x, z, level, dir) then
		return false, string.format("Wall edge already occupied at (%d, %d, %d, %s)", x, z, level, dir)
	end
	
	-- Check structural support (placeholder)
	local supportOk, supportReason = BuildPlacementService.ValidateSupport("Wall", x, z, level, dir)
	if not supportOk then
		return false, "Wall not supported: " .. supportReason
	end
	
	return true, ""
end

--[[
	ValidateRamp - Validate ramp placement
	
	@param x: grid X coordinate
	@param z: grid Z coordinate
	@param level: vertical level
	@param rot: rotation in degrees (0, 90, 180, 270)
	@return ok: boolean - true if placement is valid
	@return reason: string - explanation if invalid, empty if valid
]]
function BuildPlacementService.ValidateRamp(x, z, level, rot)
	assert(BuildGridService, "BuildPlacementService not initialized")
	
	-- Sanity check: valid rotation
	if type(rot) ~= "number" then
		return false, string.format("Ramp rotation must be number, got %s", type(rot))
	end
	if not VALID_ROTATIONS[rot] then
		return false, string.format("Ramp rotation %s is invalid, must be 0/90/180/270", tostring(rot))
	end
	
	-- Check bounds
	local boundsOk, boundsReason = CheckBounds(x, z, level)
	if not boundsOk then
		return false, "Ramp placement out of bounds: " .. boundsReason
	end
	
	-- Check if already occupied
	if not BuildGridService:CanPlaceRamp(x, z, level, rot) then
		return false, string.format("Ramp slot already occupied at (%d, %d, %d, %d°)", x, z, level, rot)
	end
	
	-- Check structural support (placeholder)
	local supportOk, supportReason = BuildPlacementService.ValidateSupport("Ramp", x, z, level, rot)
	if not supportOk then
		return false, "Ramp not supported: " .. supportReason
	end
	
	return true, ""
end

-- Configuration setters (for when bounds are determined)
function BuildPlacementService.SetBounds(minX, maxX, minZ, maxZ, minLevel, maxLevel)
	CONFIG.minX = minX
	CONFIG.maxX = maxX
	CONFIG.minZ = minZ
	CONFIG.maxZ = maxZ
	CONFIG.minLevel = minLevel or CONFIG.minLevel
	CONFIG.maxLevel = maxLevel or CONFIG.maxLevel
	print(string.format("[BuildPlacementService] Bounds set: X[%s,%s] Z[%s,%s] Level[%d,%d]",
		tostring(minX), tostring(maxX), tostring(minZ), tostring(maxZ), CONFIG.minLevel, CONFIG.maxLevel))
end

return BuildPlacementService
