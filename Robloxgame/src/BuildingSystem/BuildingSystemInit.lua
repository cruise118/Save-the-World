--[[
	BuildingSystemInit.lua
	Main initialization module for the building system
	Exports all services and provides initialization
]]

local BuildConfig = require(script.Parent.BuildConfig)
local BuildGridService = require(script.Parent.BuildGridService)
local BuildPieceFactory = require(script.Parent.BuildPieceFactory)
local BuildSupportService = require(script.Parent.BuildSupportService)
local BuildPlacementService = require(script.Parent.BuildPlacementService)

local BuildingSystem = {}

-- Initialize the building system
function BuildingSystem.Initialize()
	-- Create service instances
	local gridService = BuildGridService.new()
	local pieceFactory = BuildPieceFactory.new()
	local supportService = BuildSupportService.new(gridService, pieceFactory)
	local placementService = BuildPlacementService.new(gridService, pieceFactory, supportService)
	
	return {
		Config = BuildConfig,
		GridService = gridService,
		PieceFactory = pieceFactory,
		SupportService = supportService,
		PlacementService = placementService
	}
end

return BuildingSystem
