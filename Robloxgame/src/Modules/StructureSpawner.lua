--[[
	StructureSpawner.lua
	Helper functions to spawn basic placeholder structures for testing
	
	Usage:
		local StructureSpawner = require(game.ServerScriptService.Modules.StructureSpawner)
		
		-- Spawn a wall
		local wall = StructureSpawner.SpawnWall(Vector3.new(0, 4, 10))
		
		-- Spawn a floor
		local floor = StructureSpawner.SpawnFloor(Vector3.new(0, 0, 0))
--]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local StructureSpawner = {}

-- Get or create the Structures folder in workspace
local function GetStructuresFolder()
	local folder = workspace:FindFirstChild("Structures")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Structures"
		folder.Parent = workspace
	end
	return folder
end

-- Get or create the Traps folder in workspace
local function GetTrapsFolder()
	local folder = workspace:FindFirstChild("Traps")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Traps"
		folder.Parent = workspace
	end
	return folder
end

-- Spawn a wall structure
function StructureSpawner.SpawnWall(position: Vector3, orientationY: number?): Part
	assert(RunService:IsServer(), "StructureSpawner must run on the server")
	assert(typeof(position) == "Vector3", "position must be a Vector3")
	
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Size = Vector3.new(8, 8, 1)
	wall.Position = position
	wall.Anchored = true
	wall.CanCollide = true
	wall.Material = Enum.Material.Concrete
	wall.Color = Color3.fromRGB(150, 150, 150)
	
	if orientationY then
		wall.Orientation = Vector3.new(0, orientationY, 0)
	end
	
	-- Set attributes
	wall:SetAttribute("MaxHealth", 200)
	wall:SetAttribute("Health", 200)
	wall:SetAttribute("Destroyed", false)
	
	-- Tag as Structure
	CollectionService:AddTag(wall, "Structure")
	
	-- Parent to workspace
	wall.Parent = GetStructuresFolder()
	
	return wall
end

-- Spawn a floor structure
function StructureSpawner.SpawnFloor(position: Vector3, orientationY: number?): Part
	assert(RunService:IsServer(), "StructureSpawner must run on the server")
	assert(typeof(position) == "Vector3", "position must be a Vector3")
	
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(8, 1, 8)
	floor.Position = position
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.Concrete
	floor.Color = Color3.fromRGB(120, 120, 120)
	
	if orientationY then
		floor.Orientation = Vector3.new(0, orientationY, 0)
	end
	
	-- Set attributes
	floor:SetAttribute("MaxHealth", 150)
	floor:SetAttribute("Health", 150)
	floor:SetAttribute("Destroyed", false)
	
	-- Tag as Structure
	CollectionService:AddTag(floor, "Structure")
	
	-- Parent to workspace
	floor.Parent = GetStructuresFolder()
	
	return floor
end

-- Spawn a spike trap (does not take damage, just triggers on touch)
function StructureSpawner.SpawnSpikeTrap(position: Vector3, orientationY: number?): Part
	assert(RunService:IsServer(), "StructureSpawner must run on the server")
	assert(typeof(position) == "Vector3", "position must be a Vector3")
	
	local trap = Instance.new("Part")
	trap.Name = "SpikeTrap"
	trap.Size = Vector3.new(6, 0.5, 6)
	trap.Position = position
	trap.Anchored = true
	trap.CanCollide = false -- Zombies can walk over it
	trap.Material = Enum.Material.Metal
	trap.Color = Color3.fromRGB(180, 50, 50) -- Reddish for danger
	
	if orientationY then
		trap.Orientation = Vector3.new(0, orientationY, 0)
	end
	
	-- Parent to workspace.Traps (traps don't need structure tag, they're managed by TrapService)
	trap.Parent = GetTrapsFolder()
	
	return trap
end

return StructureSpawner
