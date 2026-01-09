--[[
	BuildService.lua
	Server-authoritative building placement system with grid-based validation
	
	Usage:
		local BuildService = require(game.ServerScriptService.Modules.BuildService)
		local buildService = BuildService.new()
		
		-- Place structures via RemoteEvents
		local success, part, err = buildService:PlaceFloor(player, position, rotation)
--]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildService = {}
BuildService.__index = BuildService

-- Constants
local TILE_SIZE = 16
local FLOOR_SIZE = Vector3.new(TILE_SIZE, 1, TILE_SIZE)
local WALL_SIZE = Vector3.new(TILE_SIZE, 8, 1)
local RAMP_SIZE = Vector3.new(TILE_SIZE, 1, TILE_SIZE)  -- Same footprint as floor
local FLOOR_Y = 0.5  -- Consistent floor placement height

-- Helper to get or create folders
local function GetStructuresFolder()
	local folder = workspace:FindFirstChild("Structures")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Structures"
		folder.Parent = workspace
	end
	return folder
end

local function GetTrapsFolder()
	local folder = workspace:FindFirstChild("Traps")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Traps"
		folder.Parent = workspace
	end
	return folder
end

-- Snap position to grid
local function SnapToGrid(position: Vector3): Vector3
	local x = math.floor((position.X / TILE_SIZE) + 0.5) * TILE_SIZE
	local z = math.floor((position.Z / TILE_SIZE) + 0.5) * TILE_SIZE
	return Vector3.new(x, FLOOR_Y, z)
end

-- Get grid key from position
local function GetGridKey(position: Vector3): string
	local snapped = SnapToGrid(position)
	return string.format("%d_%d", snapped.X, snapped.Z)
end

-- Create a new BuildService instance
function BuildService.new(config)
	assert(RunService:IsServer(), "BuildService must run on the server")
	
	local self = setmetatable({}, BuildService)
	
	-- Config with defaults
	self.config = {
		maxBuildDistance = 50,  -- Max distance from player to build
		debug = false,
	}
	
	if config then
		for k, v in pairs(config) do
			self.config[k] = v
		end
	end
	
	-- Grid tracking
	self.floorGrid = {}  -- { [gridKey] = floorPart }
	self.partToGrid = {}  -- { [floorPart] = gridKey }
	
	-- Dependencies (injected or retrieved)
	self.trapService = nil  -- Will be set externally
	
	return self
end

-- Set TrapService reference
function BuildService:SetTrapService(trapService)
	self.trapService = trapService
end

-- Validate build distance
local function ValidateBuildDistance(player, position, maxDistance): (boolean, string?)
	local character = player.Character
	if not character then
		return false, "Character not found"
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false, "HumanoidRootPart not found"
	end
	
	local distance = (rootPart.Position - position).Magnitude
	if distance > maxDistance then
		return false, "Too far to build (max " .. maxDistance .. " studs)"
	end
	
	return true
end

-- Place a floor tile
function BuildService:PlaceFloor(player: Player, position: Vector3, rotationY: number): (boolean, Part?, string?)
	-- Validate distance
	local valid, err = ValidateBuildDistance(player, position, self.config.maxBuildDistance)
	if not valid then
		return false, nil, err
	end
	
	-- Snap to grid
	local snappedPos = SnapToGrid(position)
	local gridKey = GetGridKey(snappedPos)
	
	-- Check for overlap
	if self.floorGrid[gridKey] then
		return false, nil, "Floor already exists at this location"
	end
	
	-- Create floor
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = FLOOR_SIZE
	floor.Position = snappedPos
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.Concrete
	floor.Color = Color3.fromRGB(120, 120, 120)
	floor.Orientation = Vector3.new(0, rotationY or 0, 0)
	
	-- Set attributes
	floor:SetAttribute("MaxHealth", 150)
	floor:SetAttribute("Health", 150)
	floor:SetAttribute("Destroyed", false)
	floor:SetAttribute("GridKey", gridKey)
	
	-- Tag as Structure
	CollectionService:AddTag(floor, "Structure")
	
	-- Parent to workspace
	floor.Parent = GetStructuresFolder()
	
	-- Track in grid
	self.floorGrid[gridKey] = floor
	self.partToGrid[floor] = gridKey
	
	-- Cleanup on removal
	floor.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self.floorGrid[gridKey] = nil
			self.partToGrid[floor] = nil
		end
	end)
	
	if self.config.debug then
		print("[BuildService] Placed floor at", gridKey)
	end
	
	return true, floor, nil
end

-- Place a wall on floor edge
function BuildService:PlaceWall(player: Player, position: Vector3, rotationY: number): (boolean, Part?, string?)
	-- Validate distance
	local valid, err = ValidateBuildDistance(player, position, self.config.maxBuildDistance)
	if not valid then
		return false, nil, err
	end
	
	-- Snap to nearest grid position
	local snappedPos = SnapToGrid(position)
	
	-- Find closest floor tile
	local closestFloor = nil
	local closestDist = math.huge
	local checkDistance = TILE_SIZE * 1.5
	
	for gridKey, floorPart in pairs(self.floorGrid) do
		if floorPart and floorPart.Parent then
			local dist = (floorPart.Position - position).Magnitude
			if dist < closestDist and dist <= checkDistance then
				closestDist = dist
				closestFloor = floorPart
			end
		end
	end
	
	if not closestFloor then
		return false, nil, "Wall must be placed adjacent to a floor"
	end
	
	-- Determine which edge of the floor is closest (North, South, East, West)
	local floorPos = closestFloor.Position
	local relativePos = position - floorPos
	local halfTile = TILE_SIZE / 2
	
	local wallPos, wallOrientation
	
	-- Determine edge based on which component is larger
	if math.abs(relativePos.X) > math.abs(relativePos.Z) then
		-- East or West edge
		if relativePos.X > 0 then
			-- East edge (+X)
			wallPos = Vector3.new(floorPos.X + halfTile, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z)
			wallOrientation = Vector3.new(0, 90, 0)  -- Wall faces Z direction
		else
			-- West edge (-X)
			wallPos = Vector3.new(floorPos.X - halfTile, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z)
			wallOrientation = Vector3.new(0, 90, 0)
		end
	else
		-- North or South edge
		if relativePos.Z > 0 then
			-- North edge (+Z)
			wallPos = Vector3.new(floorPos.X, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z + halfTile)
			wallOrientation = Vector3.new(0, 0, 0)  -- Wall faces X direction
		else
			-- South edge (-Z)
			wallPos = Vector3.new(floorPos.X, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z - halfTile)
			wallOrientation = Vector3.new(0, 0, 0)
		end
	end
	
	-- Create wall
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Size = WALL_SIZE
	wall.Position = wallPos
	wall.Anchored = true
	wall.CanCollide = true
	wall.Material = Enum.Material.Concrete
	wall.Color = Color3.fromRGB(150, 150, 150)
	wall.Orientation = wallOrientation
	
	-- Set attributes
	wall:SetAttribute("MaxHealth", 200)
	wall:SetAttribute("Health", 200)
	wall:SetAttribute("Destroyed", false)
	
	-- Tag as Structure
	CollectionService:AddTag(wall, "Structure")
	
	-- Parent to workspace
	wall.Parent = GetStructuresFolder()
	
	if self.config.debug then
		print("[BuildService] Placed wall at edge:", wallPos, "orientation:", wallOrientation)
	end
	
	return true, wall, nil
end

-- Place a trap on a floor
function BuildService:PlaceFloorTrap(player: Player, floorPart: BasePart, trapType: string): (boolean, Part?, string?)
	-- Validate floor
	if not floorPart or not floorPart.Parent then
		return false, nil, "Invalid floor part"
	end
	
	-- Check if floor already has a trap
	if floorPart:GetAttribute("FloorHasTrap") then
		return false, nil, "Floor already has a trap"
	end
	
	-- Validate distance
	local valid, err = ValidateBuildDistance(player, floorPart.Position, self.config.maxBuildDistance)
	if not valid then
		return false, nil, err
	end
	
	-- Only spike traps for MVP
	if trapType ~= "spike" then
		return false, nil, "Unknown trap type: " .. trapType
	end
	
	-- Create trap
	local trap = Instance.new("Part")
	trap.Name = "SpikeTrap"
	trap.Size = Vector3.new(TILE_SIZE - 0.2, 0.5, TILE_SIZE - 0.2)  -- Slightly smaller than floor
	trap.Position = Vector3.new(floorPart.Position.X, floorPart.Position.Y + 0.75, floorPart.Position.Z)
	trap.Anchored = true
	trap.CanCollide = false  -- Zombies walk over it
	trap.Material = Enum.Material.Metal
	trap.Color = Color3.fromRGB(180, 50, 50)  -- Red for danger
	trap.Orientation = floorPart.Orientation
	
	-- Store reference to floor
	trap:SetAttribute("FloorPart", floorPart:GetFullName())
	
	-- Parent to workspace
	trap.Parent = GetTrapsFolder()
	
	-- Mark floor as having a trap
	floorPart:SetAttribute("FloorHasTrap", true)
	floorPart:SetAttribute("TrapId", trap:GetFullName())
	
	-- Register with TrapService
	if self.trapService then
		self.trapService:RegisterSpikeTrap(trap)
	end
	
	-- Cleanup trap marker when trap is removed
	trap.AncestryChanged:Connect(function(_, parent)
		if not parent and floorPart and floorPart.Parent then
			floorPart:SetAttribute("FloorHasTrap", false)
			floorPart:SetAttribute("TrapId", nil)
		end
	end)
	
	if self.config.debug then
		print("[BuildService] Placed spike trap on floor")
	end
	
	return true, trap, nil
end

-- Delete a structure or trap
function BuildService:DeleteStructure(player: Player, part: BasePart): (boolean, string?)
	if not part or not part.Parent then
		return false, "Invalid part"
	end
	
	-- Validate distance
	local valid, err = ValidateBuildDistance(player, part.Position, self.config.maxBuildDistance)
	if not valid then
		return false, err
	end
	
	-- Remove from grid if it's a floor
	local gridKey = self.partToGrid[part]
	if gridKey then
		self.floorGrid[gridKey] = nil
		self.partToGrid[part] = nil
	end
	
	-- Destroy the part
	part:Destroy()
	
	if self.config.debug then
		print("[BuildService] Deleted structure:", part.Name)
	end
	
	return true, nil
end

-- Get floor at position (for trap placement)
function BuildService:GetFloorAtPosition(position: Vector3): Part?
	local gridKey = GetGridKey(position)
	return self.floorGrid[gridKey]
end

-- Place a ramp (for going up levels)
function BuildService:PlaceRamp(player: Player, position: Vector3, rotationY: number): (boolean, Part?, string?)
	-- Validate distance
	local valid, err = ValidateBuildDistance(player, position, self.config.maxBuildDistance)
	if not valid then
		return false, nil, err
	end
	
	-- Snap to grid
	local snappedPos = SnapToGrid(position)
	
	-- Create ramp as a WedgePart
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Size = RAMP_SIZE
	ramp.Position = Vector3.new(snappedPos.X, FLOOR_Y + RAMP_SIZE.Y / 2, snappedPos.Z)
	ramp.Anchored = true
	ramp.CanCollide = true
	ramp.Material = Enum.Material.Concrete
	ramp.Color = Color3.fromRGB(130, 130, 100)
	ramp.Orientation = Vector3.new(0, rotationY or 0, 0)
	
	-- Set attributes
	ramp:SetAttribute("MaxHealth", 150)
	ramp:SetAttribute("Health", 150)
	ramp:SetAttribute("Destroyed", false)
	
	-- Tag as Structure
	CollectionService:AddTag(ramp, "Structure")
	
	-- Parent to workspace
	ramp.Parent = GetStructuresFolder()
	
	if self.config.debug then
		print("[BuildService] Placed ramp at", snappedPos)
	end
	
	return true, ramp, nil
end

-- Place a wall with a door (players can pass through)
function BuildService:PlaceWallWithDoor(player: Player, position: Vector3, rotationY: number): (boolean, Model?, string?)
	-- Validate distance
	local valid, err = ValidateBuildDistance(player, position, self.config.maxBuildDistance)
	if not valid then
		return false, nil, err
	end
	
	-- Snap to nearest grid position
	local snappedPos = SnapToGrid(position)
	
	-- Find closest floor tile (same logic as regular wall)
	local closestFloor = nil
	local closestDist = math.huge
	local checkDistance = TILE_SIZE * 1.5
	
	for gridKey, floorPart in pairs(self.floorGrid) do
		if floorPart and floorPart.Parent then
			local dist = (floorPart.Position - position).Magnitude
			if dist < closestDist and dist <= checkDistance then
				closestDist = dist
				closestFloor = floorPart
			end
		end
	end
	
	if not closestFloor then
		return false, nil, "Wall must be placed adjacent to a floor"
	end
	
	-- Determine which edge of the floor is closest
	local floorPos = closestFloor.Position
	local relativePos = position - floorPos
	local halfTile = TILE_SIZE / 2
	
	local wallPos, wallOrientation
	
	if math.abs(relativePos.X) > math.abs(relativePos.Z) then
		if relativePos.X > 0 then
			wallPos = Vector3.new(floorPos.X + halfTile, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z)
			wallOrientation = Vector3.new(0, 90, 0)
		else
			wallPos = Vector3.new(floorPos.X - halfTile, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z)
			wallOrientation = Vector3.new(0, 90, 0)
		end
	else
		if relativePos.Z > 0 then
			wallPos = Vector3.new(floorPos.X, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z + halfTile)
			wallOrientation = Vector3.new(0, 0, 0)
		else
			wallPos = Vector3.new(floorPos.X, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z - halfTile)
			wallOrientation = Vector3.new(0, 0, 0)
		end
	end
	
	-- Create model to hold wall parts
	local wallModel = Instance.new("Model")
	wallModel.Name = "WallWithDoor"
	
	-- Door opening dimensions (3 studs wide, 6 studs tall, centered)
	local doorWidth = 3
	local doorHeight = 6
	local sideWidth = (TILE_SIZE - doorWidth) / 2
	
	-- Create top part (above door)
	local topPart = Instance.new("Part")
	topPart.Name = "WallTop"
	topPart.Size = Vector3.new(TILE_SIZE, WALL_SIZE.Y - doorHeight, WALL_SIZE.Z)
	topPart.Position = wallPos + Vector3.new(0, doorHeight / 2, 0)
	topPart.Anchored = true
	topPart.CanCollide = true
	topPart.Material = Enum.Material.Concrete
	topPart.Color = Color3.fromRGB(150, 150, 150)
	topPart.Orientation = wallOrientation
	topPart.Parent = wallModel
	
	-- Create left side part
	local leftPart = Instance.new("Part")
	leftPart.Name = "WallLeft"
	leftPart.Size = Vector3.new(sideWidth, doorHeight, WALL_SIZE.Z)
	leftPart.Anchored = true
	leftPart.CanCollide = true
	leftPart.Material = Enum.Material.Concrete
	leftPart.Color = Color3.fromRGB(150, 150, 150)
	leftPart.Orientation = wallOrientation
	leftPart.Parent = wallModel
	
	-- Create right side part
	local rightPart = Instance.new("Part")
	rightPart.Name = "WallRight"
	rightPart.Size = Vector3.new(sideWidth, doorHeight, WALL_SIZE.Z)
	rightPart.Anchored = true
	rightPart.CanCollide = true
	rightPart.Material = Enum.Material.Concrete
	rightPart.Color = Color3.fromRGB(150, 150, 150)
	rightPart.Orientation = wallOrientation
	rightPart.Parent = wallModel
	
	-- Position side parts based on orientation
	if wallOrientation.Y == 90 then
		-- Wall faces Z direction
		leftPart.Position = wallPos + Vector3.new(0, -(WALL_SIZE.Y - doorHeight) / 2, sideWidth + doorWidth / 2)
		rightPart.Position = wallPos + Vector3.new(0, -(WALL_SIZE.Y - doorHeight) / 2, -(sideWidth + doorWidth / 2))
	else
		-- Wall faces X direction
		leftPart.Position = wallPos + Vector3.new(-(sideWidth + doorWidth / 2), -(WALL_SIZE.Y - doorHeight) / 2, 0)
		rightPart.Position = wallPos + Vector3.new(sideWidth + doorWidth / 2, -(WALL_SIZE.Y - doorHeight) / 2, 0)
	end
	
	-- Set PrimaryPart
	wallModel.PrimaryPart = topPart
	
	-- Set attributes on model
	wallModel:SetAttribute("MaxHealth", 200)
	wallModel:SetAttribute("Health", 200)
	wallModel:SetAttribute("Destroyed", false)
	
	-- Tag as Structure
	CollectionService:AddTag(wallModel, "Structure")
	
	-- Parent to workspace
	wallModel.Parent = GetStructuresFolder()
	
	if self.config.debug then
		print("[BuildService] Placed wall with door at:", wallPos)
	end
	
	return true, wallModel, nil
end

-- Place a wall with a window (hole in the middle)
function BuildService:PlaceWallWithWindow(player: Player, position: Vector3, rotationY: number): (boolean, Model?, string?)
	-- Validate distance
	local valid, err = ValidateBuildDistance(player, position, self.config.maxBuildDistance)
	if not valid then
		return false, nil, err
	end
	
	-- Snap to nearest grid position
	local snappedPos = SnapToGrid(position)
	
	-- Find closest floor tile (same logic as regular wall)
	local closestFloor = nil
	local closestDist = math.huge
	local checkDistance = TILE_SIZE * 1.5
	
	for gridKey, floorPart in pairs(self.floorGrid) do
		if floorPart and floorPart.Parent then
			local dist = (floorPart.Position - position).Magnitude
			if dist < closestDist and dist <= checkDistance then
				closestDist = dist
				closestFloor = floorPart
			end
		end
	end
	
	if not closestFloor then
		return false, nil, "Wall must be placed adjacent to a floor"
	end
	
	-- Determine which edge of the floor is closest
	local floorPos = closestFloor.Position
	local relativePos = position - floorPos
	local halfTile = TILE_SIZE / 2
	
	local wallPos, wallOrientation
	
	if math.abs(relativePos.X) > math.abs(relativePos.Z) then
		if relativePos.X > 0 then
			wallPos = Vector3.new(floorPos.X + halfTile, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z)
			wallOrientation = Vector3.new(0, 90, 0)
		else
			wallPos = Vector3.new(floorPos.X - halfTile, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z)
			wallOrientation = Vector3.new(0, 90, 0)
		end
	else
		if relativePos.Z > 0 then
			wallPos = Vector3.new(floorPos.X, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z + halfTile)
			wallOrientation = Vector3.new(0, 0, 0)
		else
			wallPos = Vector3.new(floorPos.X, WALL_SIZE.Y / 2 + FLOOR_Y, floorPos.Z - halfTile)
			wallOrientation = Vector3.new(0, 0, 0)
		end
	end
	
	-- Create model to hold wall parts
	local wallModel = Instance.new("Model")
	wallModel.Name = "WallWithWindow"
	
	-- Window opening dimensions (4 studs wide, 3 studs tall, centered vertically)
	local windowWidth = 4
	local windowHeight = 3
	local sideWidth = (TILE_SIZE - windowWidth) / 2
	local bottomHeight = (WALL_SIZE.Y - windowHeight) / 2
	local topHeight = WALL_SIZE.Y - windowHeight - bottomHeight
	
	-- Create bottom part (below window)
	local bottomPart = Instance.new("Part")
	bottomPart.Name = "WallBottom"
	bottomPart.Size = Vector3.new(TILE_SIZE, bottomHeight, WALL_SIZE.Z)
	bottomPart.Position = wallPos - Vector3.new(0, (WALL_SIZE.Y - bottomHeight) / 2, 0)
	bottomPart.Anchored = true
	bottomPart.CanCollide = true
	bottomPart.Material = Enum.Material.Concrete
	bottomPart.Color = Color3.fromRGB(150, 150, 150)
	bottomPart.Orientation = wallOrientation
	bottomPart.Parent = wallModel
	
	-- Create top part (above window)
	local topPart = Instance.new("Part")
	topPart.Name = "WallTop"
	topPart.Size = Vector3.new(TILE_SIZE, topHeight, WALL_SIZE.Z)
	topPart.Position = wallPos + Vector3.new(0, (WALL_SIZE.Y - topHeight) / 2, 0)
	topPart.Anchored = true
	topPart.CanCollide = true
	topPart.Material = Enum.Material.Concrete
	topPart.Color = Color3.fromRGB(150, 150, 150)
	topPart.Orientation = wallOrientation
	topPart.Parent = wallModel
	
	-- Create left side part (beside window)
	local leftPart = Instance.new("Part")
	leftPart.Name = "WallLeft"
	leftPart.Size = Vector3.new(sideWidth, windowHeight, WALL_SIZE.Z)
	leftPart.Anchored = true
	leftPart.CanCollide = true
	leftPart.Material = Enum.Material.Concrete
	leftPart.Color = Color3.fromRGB(150, 150, 150)
	leftPart.Orientation = wallOrientation
	leftPart.Parent = wallModel
	
	-- Create right side part (beside window)
	local rightPart = Instance.new("Part")
	rightPart.Name = "WallRight"
	rightPart.Size = Vector3.new(sideWidth, windowHeight, WALL_SIZE.Z)
	rightPart.Anchored = true
	rightPart.CanCollide = true
	rightPart.Material = Enum.Material.Concrete
	rightPart.Color = Color3.fromRGB(150, 150, 150)
	rightPart.Orientation = wallOrientation
	rightPart.Parent = wallModel
	
	-- Position side parts based on orientation
	if wallOrientation.Y == 90 then
		-- Wall faces Z direction
		leftPart.Position = wallPos + Vector3.new(0, 0, sideWidth + windowWidth / 2)
		rightPart.Position = wallPos + Vector3.new(0, 0, -(sideWidth + windowWidth / 2))
	else
		-- Wall faces X direction
		leftPart.Position = wallPos + Vector3.new(-(sideWidth + windowWidth / 2), 0, 0)
		rightPart.Position = wallPos + Vector3.new(sideWidth + windowWidth / 2, 0, 0)
	end
	
	-- Set PrimaryPart
	wallModel.PrimaryPart = bottomPart
	
	-- Set attributes on model
	wallModel:SetAttribute("MaxHealth", 200)
	wallModel:SetAttribute("Health", 200)
	wallModel:SetAttribute("Destroyed", false)
	
	-- Tag as Structure
	CollectionService:AddTag(wallModel, "Structure")
	
	-- Parent to workspace
	wallModel.Parent = GetStructuresFolder()
	
	if self.config.debug then
		print("[BuildService] Placed wall with window at:", wallPos)
	end
	
	return true, wallModel, nil
end

-- Cleanup
function BuildService:Destroy()
	self.floorGrid = {}
	self.partToGrid = {}
	self.trapService = nil
end

return BuildService
