--[[
	ExampleUsage.lua
	Example script demonstrating the building system functionality
	This can be used for testing and as documentation
]]

local BuildingSystem = require(script.Parent.BuildingSystem.BuildingSystemInit)

local function runExample()
	print("=== Building System Example ===")
	
	-- Initialize the building system
	local system = BuildingSystem.Initialize()
	local placement = system.PlacementService
	local config = system.Config
	
	print("\n1. Testing Floor Placement at Ground Level")
	-- Place a floor at ground level (level 0)
	local success, message, metadata = placement:PlaceStructure(
		config.StructureType.Floor,
		0, 0, -- world X, Z
		0, -- level (ground)
		0, -- rotation
		"Wood" -- material
	)
	print("Place floor at (0,0,0):", success, message)
	if metadata then
		print("  Structure ID:", metadata.Id)
		print("  HP:", metadata.CurrentHP, "/", metadata.MaxHP)
	end
	
	print("\n2. Testing Wall Placement on Floor")
	-- Place a wall on the floor
	success, message, metadata = placement:PlaceStructure(
		config.StructureType.Wall,
		0, 0, -- same position
		0, -- same level
		90, -- rotation 90 degrees
		"Wood"
	)
	print("Place wall at (0,0,0):", success, message)
	
	print("\n3. Testing Floor Above Floor")
	-- Place a floor above the first floor
	success, message, metadata = placement:PlaceStructure(
		config.StructureType.Floor,
		0, 0,
		1, -- level 1 (above ground)
		0,
		"Wood"
	)
	print("Place floor at (0,0,1):", success, message)
	if metadata then
		print("  Structure ID:", metadata.Id)
	end
	
	print("\n4. Testing Invalid Placement (No Support)")
	-- Try to place a floor without support
	success, message, metadata = placement:PlaceStructure(
		config.StructureType.Floor,
		8, 8, -- different position
		2, -- level 2 without level 1 below
		0,
		"Wood"
	)
	print("Place unsupported floor at (8,8,2):", success, message)
	
	print("\n5. Testing Ramp Placement")
	-- Place a ramp at ground level
	success, message, metadata = placement:PlaceStructure(
		config.StructureType.Ramp,
		4, 4,
		0,
		180, -- facing down
		"Wood"
	)
	print("Place ramp at (4,4,0):", success, message)
	
	print("\n6. Testing Preview System")
	-- Create a preview for validation
	local preview = placement:CreatePreview(
		config.StructureType.Floor,
		12, 12,
		0,
		0,
		"Stone"
	)
	print("Preview at (12,12,0):")
	print("  Is Valid:", preview.IsValid)
	print("  Grid Position:", preview.GridX, preview.GridZ, preview.Level)
	if not preview.IsValid then
		print("  Error:", preview.ValidationResult.ErrorMessage)
	end
	
	print("\n7. Testing Structure Removal")
	-- Remove the first floor and see cascade destruction
	local gridService = system.GridService
	local gridX, gridZ = gridService:WorldToGrid(0, 0)
	success, message, result = placement:RemoveStructure(gridX, gridZ, 0, config.StructureType.Floor)
	print("Remove floor at (0,0,0):", success, message)
	if result then
		print("  Removed:", result.RemovedStructure.Id)
		print("  Cascade destroyed:", #result.CascadeDestroyed, "structures")
		for i, destroyed in ipairs(result.CascadeDestroyed) do
			print("    -", destroyed.Type, "at", destroyed.GridX, destroyed.GridZ, destroyed.Level)
		end
	end
	
	print("\n8. Testing Overlap Prevention")
	-- Try to place a structure where one already exists
	success, message, metadata = placement:PlaceStructure(
		config.StructureType.Ramp,
		4, 4, -- same as ramp above
		0,
		0,
		"Wood"
	)
	print("Place overlapping ramp at (4,4,0):", success, message)
	
	print("\n9. Testing Grid Coordinate Conversion")
	-- Test coordinate snapping
	local snappedX, snappedZ = gridService:SnapToGrid(6.7, 3.2)
	print("Snap (6.7, 3.2) to grid:", snappedX, snappedZ)
	
	local worldX, worldY, worldZ = gridService:GridToWorld(2, 3, 1)
	print("Grid (2,3,1) to world:", worldX, worldY, worldZ)
	
	print("\n10. Querying Structures in Area")
	-- Get all structures near origin
	local nearbyStructures = placement:GetStructuresInArea(0, 0, 5)
	print("Structures within 5 tiles of origin:", #nearbyStructures)
	for i, structure in ipairs(nearbyStructures) do
		print("  -", structure.Type, "at grid", structure.GridX, structure.GridZ, "level", structure.Level)
	end
	
	print("\n=== Example Complete ===")
end

-- Run the example
local success, err = pcall(runExample)
if not success then
	print("ERROR:", err)
end
