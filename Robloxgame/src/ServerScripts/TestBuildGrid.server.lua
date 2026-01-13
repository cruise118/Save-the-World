--[[
	TestBuildGrid
	Test script for BuildGridService
	
	Tests:
	- Structure placement (floor, wall, ramp)
	- Occupancy checking
	- Structure retrieval
]]

local ServerScriptService = game:GetService("ServerScriptService")

-- Wait for modules to load
local Modules = ServerScriptService:WaitForChild("Modules")
local BuildGridService = require(Modules:WaitForChild("BuildGridService"))

print("========================================")
print("BuildGridService Test Starting...")
print("========================================")

-- Create service instance
local gridService = BuildGridService.new()

print("\n--- Constants ---")
print("Tile Size:", gridService:GetTileSize(), "studs")
print("Level Height:", gridService:GetLevelHeight(), "studs")

-- Test coordinate conversion
print("\n--- Coordinate Conversion Tests ---")
local worldPos = Vector3.new(12, 8, -12)
local x, z, level = gridService:WorldToGrid(worldPos)
print(string.format("World (%0.1f, %0.1f, %0.1f) -> Grid (%d, %d, %d)", worldPos.X, worldPos.Y, worldPos.Z, x, z, level))

local backToWorld = gridService:GridToWorld(x, z, level)
print(string.format("Grid (%d, %d, %d) -> World (%0.1f, %0.1f, %0.1f)", x, z, level, backToWorld.X, backToWorld.Y, backToWorld.Z))

-- Test placing structures
print("\n--- Placing Structures ---")

-- Place a floor at (0, 0, 0)
local floorRecord = {
	type = "Floor",
	x = 0,
	z = 0,
	level = 0,
	maxHP = 100,
	hp = 100,
	tier = "MVP"
}
print("\nChecking if can place floor at (0,0,0):", gridService:CanPlaceFloor(0, 0, 0))
local placedFloor = gridService:AddStructure(floorRecord)
print("Placed Floor:", placedFloor.id, "at", string.format("(%d,%d,%d)", placedFloor.x, placedFloor.z, placedFloor.level))
print("Can place another floor at same location:", gridService:CanPlaceFloor(0, 0, 0))

-- Place a wall at (1, 1, 0) facing North
local wallRecord = {
	type = "Wall",
	x = 1,
	z = 1,
	level = 0,
	dir = "N",
	maxHP = 100,
	hp = 100,
	tier = "MVP"
}
print("\nChecking if can place wall at (1,1,0) dir=N:", gridService:CanPlaceWall(1, 1, 0, "N"))
local placedWall = gridService:AddStructure(wallRecord)
print("Placed Wall:", placedWall.id, "at", string.format("(%d,%d,%d) dir=%s", placedWall.x, placedWall.z, placedWall.level, placedWall.dir))
print("Can place another wall at same location/direction:", gridService:CanPlaceWall(1, 1, 0, "N"))
print("Can place wall at same location but different direction (E):", gridService:CanPlaceWall(1, 1, 0, "E"))

-- Place a ramp at (2, 2, 0) with rotation 90
local rampRecord = {
	type = "Ramp",
	x = 2,
	z = 2,
	level = 0,
	rot = 90,
	maxHP = 100,
	hp = 100,
	tier = "MVP"
}
print("\nChecking if can place ramp at (2,2,0) rot=90:", gridService:CanPlaceRamp(2, 2, 0, 90))
local placedRamp = gridService:AddStructure(rampRecord)
print("Placed Ramp:", placedRamp.id, "at", string.format("(%d,%d,%d) rot=%d", placedRamp.x, placedRamp.z, placedRamp.level, placedRamp.rot))
print("Can place another ramp at same location/rotation:", gridService:CanPlaceRamp(2, 2, 0, 90))
print("Can place ramp at same location but different rotation (180):", gridService:CanPlaceRamp(2, 2, 0, 180))

-- Test structure retrieval
print("\n--- Structure Retrieval Tests ---")
local foundFloor = gridService:GetStructureAtFloor(0, 0, 0)
if foundFloor then
	print("Found Floor at (0,0,0):", foundFloor.id, "HP:", foundFloor.hp .. "/" .. foundFloor.maxHP)
else
	print("ERROR: No floor found at (0,0,0)")
end

local foundWall = gridService:GetStructureAtWall(1, 1, 0, "N")
if foundWall then
	print("Found Wall at (1,1,0) dir=N:", foundWall.id, "HP:", foundWall.hp .. "/" .. foundWall.maxHP)
else
	print("ERROR: No wall found at (1,1,0) dir=N")
end

local foundRamp = gridService:GetStructureAtRamp(2, 2, 0, 90)
if foundRamp then
	print("Found Ramp at (2,2,0) rot=90:", foundRamp.id, "HP:", foundRamp.hp .. "/" .. foundRamp.maxHP)
else
	print("ERROR: No ramp found at (2,2,0) rot=90")
end

-- Test removal
print("\n--- Structure Removal Tests ---")
print("Removing floor:", placedFloor.id)
local removed = gridService:RemoveStructure(placedFloor.id)
print("Removal successful:", removed)
print("Can now place floor at (0,0,0):", gridService:CanPlaceFloor(0, 0, 0))
local checkRemoved = gridService:GetStructureAtFloor(0, 0, 0)
print("Floor still exists at (0,0,0):", checkRemoved ~= nil)

print("\n========================================")
print("BuildGridService Test Complete!")
print("========================================")
