--[[
	BuildPieceFactory.lua
	Factory for creating structure blueprints and initializing structure data
]]

local BuildConfig = require(script.Parent.BuildConfig)

local BuildPieceFactory = {}
BuildPieceFactory.__index = BuildPieceFactory

-- Structure blueprint definitions
local Blueprints = {
	[BuildConfig.StructureType.Floor] = {
		Type = BuildConfig.StructureType.Floor,
		Size = {X = BuildConfig.TileSize, Z = BuildConfig.TileSize},
		Description = "Horizontal platform covering one tile",
		SupportsAbove = true, -- Can support structures above it
		RequiresSupport = true, -- Needs support below
		BlocksMovement = false -- Units can walk on it
	},
	
	[BuildConfig.StructureType.Wall] = {
		Type = BuildConfig.StructureType.Wall,
		Size = {X = BuildConfig.TileSize, Y = BuildConfig.WallHeight},
		Description = "Vertical barrier on tile edge",
		SupportsAbove = true, -- Can support structures above it
		RequiresSupport = true, -- Needs support below
		BlocksMovement = true, -- Blocks unit passage
		EdgeAligned = true -- Aligns to tile edges, not centers
	},
	
	[BuildConfig.StructureType.Ramp] = {
		Type = BuildConfig.StructureType.Ramp,
		Size = {X = BuildConfig.TileSize, Z = BuildConfig.TileSize, Y = BuildConfig.WallHeight},
		Description = "Inclined surface for vertical traversal",
		SupportsAbove = false, -- Cannot support structures directly above
		RequiresSupport = true, -- Needs support below
		BlocksMovement = false, -- Units can walk up it
		NoCollisionBelow = true -- No collision plate underneath
	}
}

-- Constructor
function BuildPieceFactory.new()
	local self = setmetatable({}, BuildPieceFactory)
	return self
end

-- Get blueprint for structure type
function BuildPieceFactory:GetBlueprint(structureType)
	return Blueprints[structureType]
end

-- Create structure metadata
function BuildPieceFactory:CreateStructureMetadata(structureType, gridX, gridZ, level, rotation, material)
	local blueprint = self:GetBlueprint(structureType)
	if not blueprint then
		error("Invalid structure type: " .. tostring(structureType))
	end
	
	material = material or BuildConfig.DefaultMaterial
	local materialData = BuildConfig.MaterialTier[material]
	
	if not materialData then
		error("Invalid material: " .. tostring(material))
	end
	
	-- Generate unique ID for this structure with high entropy
	-- Combines: type, position, level, timestamp, and random number to avoid collisions
	local structureId = string.format("%s_%d_%d_%d_%d_%d", 
		structureType, gridX, gridZ, level, os.time(), math.random(1000000, 9999999))
	
	return {
		-- Identity
		Id = structureId,
		Type = structureType,
		
		-- Grid position
		GridX = gridX,
		GridZ = gridZ,
		Level = level,
		Rotation = rotation,
		
		-- Material/Tier
		Material = material,
		MaxHP = materialData.MaxHP,
		CurrentHP = materialData.MaxHP,
		
		-- Blueprint reference
		Blueprint = blueprint,
		
		-- State
		IsPlaced = false,
		PlacedTime = nil,
		
		-- Support tracking (will be managed by BuildSupportService)
		SupportedBy = {}, -- List of structure IDs this depends on
		Supporting = {} -- List of structure IDs depending on this
	}
end

-- Validate structure type
function BuildPieceFactory:IsValidStructureType(structureType)
	return Blueprints[structureType] ~= nil
end

-- Get all available structure types
function BuildPieceFactory:GetAllStructureTypes()
	local types = {}
	for structureType, _ in pairs(Blueprints) do
		table.insert(types, structureType)
	end
	return types
end

-- Check if structure type requires support
function BuildPieceFactory:RequiresSupport(structureType)
	local blueprint = self:GetBlueprint(structureType)
	return blueprint and blueprint.RequiresSupport or false
end

-- Check if structure type can support others above
function BuildPieceFactory:CanSupportAbove(structureType)
	local blueprint = self:GetBlueprint(structureType)
	return blueprint and blueprint.SupportsAbove or false
end

-- Check if structure is edge-aligned (like walls)
function BuildPieceFactory:IsEdgeAligned(structureType)
	local blueprint = self:GetBlueprint(structureType)
	return blueprint and blueprint.EdgeAligned or false
end

return BuildPieceFactory
