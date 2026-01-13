--[[
	BuildPieceFactory.lua
	Creates structure instances with full metadata storage
	Handles proper parenting, tagging, and attribute setup
	
	Usage:
		local BuildPieceFactory = require(...BuildPieceFactory)
		local factory = BuildPieceFactory.new(gridService)
		
		local part, metadata = factory:CreateFloor(x, z, level, rotation)
		factory:DestroyPiece(part, metadata)
--]]

local CollectionService = game:GetService("CollectionService")

local BuildPieceFactory = {}
BuildPieceFactory.__index = BuildPieceFactory

-- Constants
local TILE_SIZE = 12
local WALL_HEIGHT = 8
local LEVEL_HEIGHT = 8

-- Piece HP configuration
local PIECE_HP = {
	floor = 150,
	wall = 200,
	ramp = 150,
}

-- Helper to get or create folders
local function GetStructuresFolder()
	local folder = workspace:FindFirstChild("Structures")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Structures"
		folder.Parent = workspace
		print("[BuildPieceFactory] Created Structures folder in Workspace")
	end
	return folder
end

-- Create new BuildPieceFactory
function BuildPieceFactory.new(buildGridService)
	local self = setmetatable({}, BuildPieceFactory)
	
	self.gridService = buildGridService
	self.structuresFolder = GetStructuresFolder()
	
	-- Track all pieces for cleanup
	self.allPieces = {}  -- {[part] = metadata}
	
	print("[BuildPieceFactory] Initialized")
	
	return self
end

-- Create a floor piece
-- Returns: (part: BasePart, metadata: table)
function BuildPieceFactory:CreateFloor(x, z, level, rotation)
	print(string.format("[BuildPieceFactory] Creating Floor at grid (%d, %d, %d) rotation=%d", x, z, level, rotation))
	
	-- Convert to world position
	local worldPos = self.gridService:GridToWorld(x, z, level)
	
	-- Create part
	local floor = Instance.new("Part")
	floor.Name = string.format("Floor_%d_%d_%d", x, z, level)
	floor.Size = Vector3.new(TILE_SIZE, 1, TILE_SIZE)
	floor.Position = worldPos
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(120, 120, 120)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	
	-- Apply rotation
	floor.CFrame = CFrame.new(worldPos) * CFrame.Angles(0, math.rad(rotation), 0)
	
	-- Tag as structure
	CollectionService:AddTag(floor, "Structure")
	
	-- Set attributes for health system
	floor:SetAttribute("MaxHealth", PIECE_HP.floor)
	floor:SetAttribute("Health", PIECE_HP.floor)
	floor:SetAttribute("Destroyed", false)
	
	-- Set grid attributes for AI/pathfinding
	floor:SetAttribute("GridX", x)
	floor:SetAttribute("GridZ", z)
	floor:SetAttribute("GridLevel", level)
	floor:SetAttribute("Rotation", rotation)
	floor:SetAttribute("PieceType", "floor")
	
	floor.Parent = self.structuresFolder
	
	-- Create metadata
	local metadata = {
		part = floor,
		pieceType = "floor",
		gridX = x,
		gridZ = z,
		gridLevel = level,
		rotation = rotation,
		maxHP = PIECE_HP.floor,
		currentHP = PIECE_HP.floor,
		supportedBy = {},  -- Will be filled by BuildSupportService
		supporting = {},    -- Will be filled by BuildSupportService
	}
	
	self.allPieces[floor] = metadata
	
	print(string.format("[BuildPieceFactory] ✓ Created Floor at world position (%.1f, %.1f, %.1f)", worldPos.X, worldPos.Y, worldPos.Z))
	
	return floor, metadata
end

-- Create a wall piece
-- Returns: (part: BasePart, metadata: table)
function BuildPieceFactory:CreateWall(x, z, level, edge)
	print(string.format("[BuildPieceFactory] Creating Wall at grid (%d, %d, %d) edge=%s", x, z, level, edge))
	
	-- Calculate wall position and rotation
	local wallPos, wallRotation = self.gridService:CalculateWallPosition(x, z, level, edge)
	
	-- Create part
	local wall = Instance.new("Part")
	wall.Name = string.format("Wall_%d_%d_%d_%s", x, z, level, edge)
	wall.Size = Vector3.new(TILE_SIZE, WALL_HEIGHT, TILE_SIZE)  -- Same footprint as floor (12x8x12)
	wall.Position = wallPos
	wall.Anchored = true
	wall.CanCollide = true
	wall.Material = Enum.Material.SmoothPlastic
	wall.Color = Color3.fromRGB(150, 150, 150)
	wall.TopSurface = Enum.SurfaceType.Smooth
	wall.BottomSurface = Enum.SurfaceType.Smooth
	
	-- Apply rotation
	wall.CFrame = CFrame.new(wallPos) * CFrame.Angles(0, math.rad(wallRotation), 0)
	
	-- Tag as structure
	CollectionService:AddTag(wall, "Structure")
	
	-- Set attributes
	wall:SetAttribute("MaxHealth", PIECE_HP.wall)
	wall:SetAttribute("Health", PIECE_HP.wall)
	wall:SetAttribute("Destroyed", false)
	wall:SetAttribute("GridX", x)
	wall:SetAttribute("GridZ", z)
	wall:SetAttribute("GridLevel", level)
	wall:SetAttribute("Edge", edge)
	wall:SetAttribute("Rotation", wallRotation)
	wall:SetAttribute("PieceType", "wall")
	
	wall.Parent = self.structuresFolder
	
	-- Create metadata
	local metadata = {
		part = wall,
		pieceType = "wall",
		gridX = x,
		gridZ = z,
		gridLevel = level,
		edge = edge,
		rotation = wallRotation,
		maxHP = PIECE_HP.wall,
		currentHP = PIECE_HP.wall,
		supportedBy = {},
		supporting = {},
	}
	
	self.allPieces[wall] = metadata
	
	print(string.format("[BuildPieceFactory] ✓ Created Wall at world position (%.1f, %.1f, %.1f)", wallPos.X, wallPos.Y, wallPos.Z))
	
	return wall, metadata
end

-- Create a ramp piece
-- Returns: (part: WedgePart, metadata: table)
function BuildPieceFactory:CreateRamp(x, z, level, rotation)
	print(string.format("[BuildPieceFactory] Creating Ramp at grid (%d, %d, %d) rotation=%d", x, z, level, rotation))
	
	-- Convert to world position
	local worldPos = self.gridService:GridToWorld(x, z, level)
	
	-- Create wedge part for ramp (same footprint as floor: 12x8x12)
	local ramp = Instance.new("WedgePart")
	ramp.Name = string.format("Ramp_%d_%d_%d_R%d", x, z, level, rotation)
	ramp.Size = Vector3.new(TILE_SIZE, WALL_HEIGHT, TILE_SIZE)  -- Width x Height x Depth (12x8x12)
	ramp.Position = worldPos + Vector3.new(0, WALL_HEIGHT / 2, 0)  -- Center vertically
	ramp.Anchored = true
	ramp.CanCollide = true
	ramp.Material = Enum.Material.SmoothPlastic
	ramp.Color = Color3.fromRGB(130, 130, 100)
	ramp.TopSurface = Enum.SurfaceType.Smooth
	ramp.BottomSurface = Enum.SurfaceType.Smooth
	
	-- Apply rotation (ramp faces in direction of rotation)
	-- Rotation 0 = ramp goes North (+Z), 90 = East (+X), 180 = South (-Z), 270 = West (-X)
	ramp.CFrame = CFrame.new(ramp.Position) * CFrame.Angles(0, math.rad(rotation), 0)
	
	-- Tag as structure
	CollectionService:AddTag(ramp, "Structure")
	
	-- Set attributes
	ramp:SetAttribute("MaxHealth", PIECE_HP.ramp)
	ramp:SetAttribute("Health", PIECE_HP.ramp)
	ramp:SetAttribute("Destroyed", false)
	ramp:SetAttribute("GridX", x)
	ramp:SetAttribute("GridZ", z)
	ramp:SetAttribute("GridLevel", level)
	ramp:SetAttribute("Rotation", rotation)
	ramp:SetAttribute("PieceType", "ramp")
	
	ramp.Parent = self.structuresFolder
	
	-- Create metadata
	local metadata = {
		part = ramp,
		pieceType = "ramp",
		gridX = x,
		gridZ = z,
		gridLevel = level,
		rotation = rotation,
		maxHP = PIECE_HP.ramp,
		currentHP = PIECE_HP.ramp,
		supportedBy = {},
		supporting = {},
	}
	
	self.allPieces[ramp] = metadata
	
	print(string.format("[BuildPieceFactory] ✓ Created Ramp at world position (%.1f, %.1f, %.1f)", worldPos.X, worldPos.Y + WALL_HEIGHT/2, worldPos.Z))
	
	return ramp, metadata
end

-- Destroy a piece and cleanup metadata
function BuildPieceFactory:DestroyPiece(part, metadata)
	if not part or not part.Parent then
		return
	end
	
	print(string.format("[BuildPieceFactory] Destroying %s at grid (%d, %d, %d)", 
		metadata.pieceType, metadata.gridX, metadata.gridZ, metadata.gridLevel))
	
	-- Remove from tracking
	self.allPieces[part] = nil
	
	-- Destroy the part
	part:Destroy()
	
	print("[BuildPieceFactory] ✓ Piece destroyed")
end

-- Get metadata for a part
function BuildPieceFactory:GetMetadata(part)
	return self.allPieces[part]
end

-- Cleanup all pieces
function BuildPieceFactory:Destroy()
	print("[BuildPieceFactory] Cleaning up all pieces...")
	
	for part, metadata in pairs(self.allPieces) do
		if part and part.Parent then
			part:Destroy()
		end
	end
	
	self.allPieces = {}
	
	print("[BuildPieceFactory] ✓ Cleanup complete")
end

return BuildPieceFactory
