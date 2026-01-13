--[[
	BuildConfig.lua
	Configuration constants for the building system
]]

local BuildConfig = {}

-- Grid and level configuration
BuildConfig.TileSize = 4 -- studs for X/Z grid alignment
BuildConfig.LevelHeight = 3 -- studs for Y (vertical) alignment
BuildConfig.WallHeight = 3 -- height of walls in studs

-- Rotation settings (in degrees)
BuildConfig.AllowedRotations = {0, 90, 180, 270}

-- Structure types
BuildConfig.StructureType = {
	Floor = "Floor",
	Wall = "Wall",
	Ramp = "Ramp"
}

-- Material/Tier system
BuildConfig.MaterialTier = {
	Wood = {
		Name = "Wood",
		MaxHP = 100,
		BuildTime = 1.0
	},
	Stone = {
		Name = "Stone",
		MaxHP = 200,
		BuildTime = 1.5
	},
	Metal = {
		Name = "Metal",
		MaxHP = 300,
		BuildTime = 2.0
	}
}

-- Default material
BuildConfig.DefaultMaterial = "Wood"

-- Support system constants
BuildConfig.TerrainSupportId = "terrain"

-- Validation error messages
BuildConfig.ValidationErrors = {
	Unsupported = "Structure must be supported (no floating builds allowed)",
	Overlap = "Cannot place structure here - position already occupied",
	OutOfBounds = "Cannot place structure outside valid grid bounds",
	InvalidRotation = "Invalid rotation angle - must be 0, 90, 180, or 270 degrees",
	InvalidStructureType = "Invalid structure type specified"
}

return BuildConfig
