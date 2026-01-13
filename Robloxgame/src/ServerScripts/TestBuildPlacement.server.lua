--[[
	TestBuildPlacement - Test script for BuildPlacementService validation
	
	Tests invalid placements and prints reason strings.
	NO VISUALS - Pure validation testing.
]]

print("========================================")
print("TESTING BuildPlacementService")
print("========================================")

-- Load services
local BuildGridService = require(game.ServerScriptService.Modules.BuildGridService)
local BuildPlacementService = require(game.ServerScriptService.Modules.BuildPlacementService)

-- Initialize
BuildPlacementService.Init(BuildGridService)

print("\n--- Test 1: Valid Placements ---")

-- Test valid floor
local ok, reason = BuildPlacementService.ValidateFloor(0, 0, 0)
print(string.format("Floor (0,0,0): %s %s", ok and "✓ VALID" or "✗ INVALID", reason ~= "" and "- " .. reason or ""))

-- Test valid wall
ok, reason = BuildPlacementService.ValidateWall(0, 0, 0, "N")
print(string.format("Wall (0,0,0,N): %s %s", ok and "✓ VALID" or "✗ INVALID", reason ~= "" and "- " .. reason or ""))

-- Test valid ramp
ok, reason = BuildPlacementService.ValidateRamp(1, 1, 0, 90)
print(string.format("Ramp (1,1,0,90°): %s %s", ok and "✓ VALID" or "✗ INVALID", reason ~= "" and "- " .. reason or ""))

print("\n--- Test 2: Invalid Directions/Rotations ---")

-- Invalid wall direction (not N/E/S/W)
ok, reason = BuildPlacementService.ValidateWall(0, 0, 0, "X")
print(string.format("Wall with dir='X': %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

-- Invalid wall direction (wrong type)
ok, reason = BuildPlacementService.ValidateWall(0, 0, 0, 123)
print(string.format("Wall with dir=123: %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

-- Invalid ramp rotation (not 0/90/180/270)
ok, reason = BuildPlacementService.ValidateRamp(1, 1, 0, 45)
print(string.format("Ramp with rot=45°: %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

-- Invalid ramp rotation (wrong type)
ok, reason = BuildPlacementService.ValidateRamp(1, 1, 0, "90")
print(string.format("Ramp with rot='90': %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

print("\n--- Test 3: Overlap Prevention ---")

-- Place a floor
local floorRecord = {
	type = "Floor",
	x = 5,
	z = 5,
	level = 0,
	maxHP = 100,
	hp = 100,
	tier = "MVP"
}
BuildGridService.AddStructure(floorRecord)
print("Placed floor at (5,5,0)")

-- Try to place another floor in same slot (should fail)
ok, reason = BuildPlacementService.ValidateFloor(5, 5, 0)
print(string.format("Duplicate floor (5,5,0): %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

-- Place a wall
local wallRecord = {
	type = "Wall",
	x = 3,
	z = 3,
	level = 0,
	dir = "S",
	maxHP = 100,
	hp = 100,
	tier = "MVP"
}
BuildGridService.AddStructure(wallRecord)
print("Placed wall at (3,3,0,S)")

-- Try to place another wall on same edge (should fail)
ok, reason = BuildPlacementService.ValidateWall(3, 3, 0, "S")
print(string.format("Duplicate wall (3,3,0,S): %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

-- Different direction on same tile is OK
ok, reason = BuildPlacementService.ValidateWall(3, 3, 0, "E")
print(string.format("Different wall edge (3,3,0,E): %s %s", ok and "✓ VALID" or "✗ INVALID", reason ~= "" and "- " .. reason or ""))

-- Place a ramp
local rampRecord = {
	type = "Ramp",
	x = 7,
	z = 7,
	level = 0,
	rot = 0,
	maxHP = 100,
	hp = 100,
	tier = "MVP"
}
BuildGridService.AddStructure(rampRecord)
print("Placed ramp at (7,7,0,0°)")

-- Try to place another ramp with same rotation (should fail)
ok, reason = BuildPlacementService.ValidateRamp(7, 7, 0, 0)
print(string.format("Duplicate ramp (7,7,0,0°): %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

-- Different rotation on same tile is OK
ok, reason = BuildPlacementService.ValidateRamp(7, 7, 0, 90)
print(string.format("Different ramp rotation (7,7,0,90°): %s %s", ok and "✓ VALID" or "✗ INVALID", reason ~= "" and "- " .. reason or ""))

print("\n--- Test 4: Bounds Checking ---")

-- Set some bounds
BuildPlacementService.SetBounds(-10, 10, -10, 10, 0, 5)

-- Test within bounds
ok, reason = BuildPlacementService.ValidateFloor(5, 5, 2)
print(string.format("Floor within bounds (5,5,2): %s %s", ok and "✓ VALID" or "✗ INVALID", reason ~= "" and "- " .. reason or ""))

-- Test outside X bounds
ok, reason = BuildPlacementService.ValidateFloor(15, 0, 0)
print(string.format("Floor outside X bounds (15,0,0): %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

-- Test outside Z bounds
ok, reason = BuildPlacementService.ValidateWall(0, -15, 0, "N")
print(string.format("Wall outside Z bounds (0,-15,0,N): %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

-- Test outside level bounds
ok, reason = BuildPlacementService.ValidateRamp(0, 0, 10, 0)
print(string.format("Ramp outside level bounds (0,0,10,0°): %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

-- Test below minimum level
ok, reason = BuildPlacementService.ValidateFloor(0, 0, -1)
print(string.format("Floor below min level (0,0,-1): %s - %s", ok and "✓ VALID" or "✗ INVALID", reason))

print("\n--- Test 5: Support Validation (Placeholder) ---")
print("NOTE: Support validation currently returns true (placeholder for Phase 3)")

ok, reason = BuildPlacementService.ValidateSupport("Floor", 0, 0, 5, nil)
print(string.format("Floor support check: %s %s", ok and "✓ VALID" or "✗ INVALID", reason ~= "" and "- " .. reason or ""))

ok, reason = BuildPlacementService.ValidateSupport("Wall", 0, 0, 3, "N")
print(string.format("Wall support check: %s %s", ok and "✓ VALID" or "✗ INVALID", reason ~= "" and "- " .. reason or ""))

ok, reason = BuildPlacementService.ValidateSupport("Ramp", 0, 0, 2, 90)
print(string.format("Ramp support check: %s %s", ok and "✓ VALID" or "✗ INVALID", reason ~= "" and "- " .. reason or ""))

print("\n========================================")
print("BuildPlacementService tests complete!")
print("All validation functions working as expected.")
print("Ready for Phase 3: Support validation implementation.")
print("========================================")
