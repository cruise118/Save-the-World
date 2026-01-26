--[[
	BuildPlacementService.lua
	Manages placement rules, validation, and preview system
]]

local BuildConfig = require(script.Parent.BuildConfig)

local BuildPlacementService = {}
BuildPlacementService.__index = BuildPlacementService

-- Validation result structure
local function createValidationResult(isValid, errorMessage, errorType)
	return {
		IsValid = isValid,
		ErrorMessage = errorMessage or "",
		ErrorType = errorType or "None"
	}
end

-- Constructor
function BuildPlacementService.new(buildGridService, buildPieceFactory, buildSupportService)
	local self = setmetatable({}, BuildPlacementService)
	
	self._gridService = buildGridService
	self._factory = buildPieceFactory
	self._supportService = buildSupportService
	
	-- Preview state
	self._currentPreview = nil
	
	return self
end

-- Validate structure placement
function BuildPlacementService:ValidatePlacement(structureType, worldX, worldZ, level, rotation, material)
	-- Validate structure type
	if not self._factory:IsValidStructureType(structureType) then
		return createValidationResult(false, BuildConfig.ValidationErrors.InvalidStructureType, "InvalidType")
	end
	
	-- Validate rotation
	if not self._gridService:IsValidRotation(rotation) then
		return createValidationResult(false, BuildConfig.ValidationErrors.InvalidRotation, "InvalidRotation")
	end
	
	-- Convert to grid coordinates
	local gridX, gridZ = self._gridService:WorldToGrid(worldX, worldZ)
	
	-- Check for overlaps
	if self._gridService:IsTileOccupied(gridX, gridZ, level, structureType) then
		return createValidationResult(false, BuildConfig.ValidationErrors.Overlap, "Overlap")
	end
	
	-- Check support requirements
	if self._factory:RequiresSupport(structureType) then
		local hasSupport, supportType = self._supportService:HasValidSupport(gridX, gridZ, level, structureType)
		if not hasSupport then
			return createValidationResult(false, BuildConfig.ValidationErrors.Unsupported, "Unsupported")
		end
	end
	
	-- All validations passed
	return createValidationResult(true)
end

-- Place a structure (after validation)
function BuildPlacementService:PlaceStructure(structureType, worldX, worldZ, level, rotation, material)
	-- Validate first
	local validation = self:ValidatePlacement(structureType, worldX, worldZ, level, rotation, material)
	if not validation.IsValid then
		return false, validation.ErrorMessage, nil
	end
	
	-- Convert to grid coordinates
	local gridX, gridZ = self._gridService:WorldToGrid(worldX, worldZ)
	
	-- Create structure metadata
	local metadata = self._factory:CreateStructureMetadata(
		structureType, 
		gridX, 
		gridZ, 
		level, 
		rotation, 
		material
	)
	
	-- Mark as placed
	metadata.IsPlaced = true
	metadata.PlacedTime = os.time()
	
	-- Occupy tile in grid
	local gridKey = self._gridService:OccupyTile(gridX, gridZ, level, structureType, metadata)
	metadata.GridKey = gridKey
	
	-- Register in support service for dependency tracking
	self._supportService:RegisterStructure(metadata)
	
	return true, "Structure placed successfully", metadata
end

-- Remove a structure and handle cascade destruction
function BuildPlacementService:RemoveStructure(gridX, gridZ, level, structureType)
	-- Get structure metadata
	local metadata = self._gridService:GetStructureAt(gridX, gridZ, level, structureType)
	if not metadata then
		return false, "No structure found at specified position", {}
	end
	
	-- Remove from grid
	self._gridService:RemoveStructure(gridX, gridZ, level, structureType)
	
	-- Calculate cascade destruction
	local cascadeDestroyList = self._supportService:CalculateCascadeDestruction(metadata.Id)
	
	-- Remove cascaded structures from grid
	local cascadeDestroyedStructures = {}
	for _, cascadeData in ipairs(cascadeDestroyList) do
		-- cascadeData now contains {id = structureId, metadata = structureMetadata}
		local meta = cascadeData.metadata
		if meta then
			self._gridService:RemoveStructure(meta.GridX, meta.GridZ, meta.Level, meta.Type)
			table.insert(cascadeDestroyedStructures, meta)
		end
	end
	
	return true, "Structure removed", {
		RemovedStructure = metadata,
		CascadeDestroyed = cascadeDestroyedStructures
	}
end

-- Create preview for placement validation
function BuildPlacementService:CreatePreview(structureType, worldX, worldZ, level, rotation, material)
	-- Validate placement
	local validation = self:ValidatePlacement(structureType, worldX, worldZ, level, rotation, material)
	
	-- Convert to grid coordinates
	local gridX, gridZ = self._gridService:WorldToGrid(worldX, worldZ)
	local worldPosX, worldPosY, worldPosZ = self._gridService:GridToWorld(gridX, gridZ, level)
	
	-- Create preview data
	self._currentPreview = {
		StructureType = structureType,
		GridX = gridX,
		GridZ = gridZ,
		Level = level,
		WorldX = worldPosX,
		WorldY = worldPosY,
		WorldZ = worldPosZ,
		Rotation = rotation,
		Material = material,
		IsValid = validation.IsValid,
		ValidationResult = validation
	}
	
	return self._currentPreview
end

-- Get current preview
function BuildPlacementService:GetCurrentPreview()
	return self._currentPreview
end

-- Clear preview
function BuildPlacementService:ClearPreview()
	self._currentPreview = nil
end

-- Get structure at world position
function BuildPlacementService:GetStructureAtWorld(worldX, worldZ, level, structureType)
	local gridX, gridZ = self._gridService:WorldToGrid(worldX, worldZ)
	return self._gridService:GetStructureAt(gridX, gridZ, level, structureType)
end

-- Get all structures in area (for queries)
function BuildPlacementService:GetStructuresInArea(worldX, worldZ, radiusInTiles)
	local centerGridX, centerGridZ = self._gridService:WorldToGrid(worldX, worldZ)
	local structures = {}
	
	-- Get all structures and filter by distance
	local allStructures = self._gridService:GetAllStructures()
	for _, structureData in ipairs(allStructures) do
		local meta = structureData.metadata
		if meta then
			local dx = meta.GridX - centerGridX
			local dz = meta.GridZ - centerGridZ
			local distance = math.sqrt(dx * dx + dz * dz)
			
			if distance <= radiusInTiles then
				table.insert(structures, meta)
			end
		end
	end
	
	return structures
end

return BuildPlacementService
