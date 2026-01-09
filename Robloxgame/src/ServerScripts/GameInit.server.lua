-- GameInit.server.lua
-- Zombie Defense MVP integration script (restart-safe)
-- Initializes all game systems and starts the wave manager

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load modules
local DamageService = require(ServerScriptService.Modules.DamageService)
local BaseCoreHealth = require(ServerScriptService.Modules.BaseCoreHealth)
local WaveManager = require(ServerScriptService.Modules.WaveManager)
local StructureHealthService = require(ServerScriptService.Modules.StructureHealthService)
local StructureSpawner = require(ServerScriptService.Modules.StructureSpawner)
local TrapService = require(ServerScriptService.Modules.TrapService)
local BuildService = require(ServerScriptService.Modules.BuildService)

-- Game state
local coreHealth = nil
local structureHealth = nil
local trapService = nil
local waveManager = nil
local buildService = nil
local gameOverConn = nil

-- Find required objects (once)
local baseCorePart = Workspace:FindFirstChild("BaseCore")
if not baseCorePart then
	error("BaseCore not found in Workspace! Please add a BasePart named 'BaseCore'.")
end

local zombieSpawnsFolder = Workspace:FindFirstChild("ZombieSpawns")
if not zombieSpawnsFolder then
	error("ZombieSpawns folder not found in Workspace! Please add a Folder named 'ZombieSpawns' with spawn point BaseParts.")
end

local zombieTemplate = ServerStorage:FindFirstChild("ZombieModel")
if not zombieTemplate then
	error("ZombieModel not found in ServerStorage! Please add a zombie Model named 'ZombieModel' with Humanoid and HumanoidRootPart.")
end

-- Collect spawn points
local spawnPoints = {}
for _, child in ipairs(zombieSpawnsFolder:GetChildren()) do
	if child:IsA("BasePart") then
		table.insert(spawnPoints, child)
	end
end

if #spawnPoints == 0 then
	error("No spawn points found in ZombieSpawns folder! Please add BaseParts to the folder.")
end

print("✓ Found BaseCore:", baseCorePart.Name)
print("✓ Found ZombieModel:", zombieTemplate.Name)
print("✓ Found", #spawnPoints, "spawn points")

-- Stop current game run and cleanup
local function StopRun()
	-- Stop wave manager
	if waveManager then
		waveManager:Stop()
		waveManager = nil
	end
	
	-- Cleanup build service
	if buildService then
		buildService:Destroy()
		buildService = nil
	end
	
	-- Cleanup trap service
	if trapService then
		trapService:Destroy()
		trapService = nil
	end
	
	-- Cleanup structure health
	if structureHealth then
		structureHealth:Destroy()
		structureHealth = nil
	end
	
	-- Cleanup base core health
	if coreHealth then
		DamageService.UnregisterBaseCore(baseCorePart)
		coreHealth:Destroy()
		coreHealth = nil
	end
	
	-- Clear structure handler
	DamageService.SetStructureDamageHandler(nil)
	
	-- Disconnect game over event
	if gameOverConn then
		gameOverConn:Disconnect()
		gameOverConn = nil
	end
	
	print("✓ Game stopped and cleaned up")
end

-- Start new game run
local function StartRun()
	-- Create Base Core health system
	coreHealth = BaseCoreHealth.new(baseCorePart, {
		maxHealth = 1000,
		clampDamage = true
	})
	
	print("✓ Base Core Health initialized with", coreHealth:GetMaxHealth(), "HP")
	
	-- Register Base Core with damage service
	DamageService.RegisterBaseCore(baseCorePart, coreHealth)
	print("✓ Base Core registered with DamageService")
	
	-- Create structure health service
	structureHealth = StructureHealthService.new({
		defaultMaxHealth = 200,
		destroyDelay = 0.05,
		debug = true -- temporary for testing
	})
	
	-- Set structure damage handler
	DamageService.SetStructureDamageHandler(function(part, amount, source)
		structureHealth:Damage(part, amount, source)
	end)
	print("✓ Structure Health Service initialized and connected to DamageService")
	
	-- Create trap service
	trapService = TrapService.new({
		spikeDamage = 15,
		hitCooldown = 0.75,
		debug = true -- temporary for testing
	})
	print("✓ Trap Service initialized")
	
	-- Create build service
	buildService = BuildService.new({
		maxBuildDistance = 50,
		debug = false
	})
	buildService:SetTrapService(trapService)
	print("✓ Build Service initialized")
	
	-- Create wave manager
	waveManager = WaveManager.new({
		baseCoreHealth = coreHealth,
		baseCorePart = baseCorePart,
		zombieTemplate = zombieTemplate,
		spawnPoints = spawnPoints,
		damageService = DamageService,
		
		-- Faster testing config
		timeBetweenWaves = 5,
		zombiesPerWave = 3,
		zombieIncrementPerWave = 2
	})
	
	print("✓ Wave Manager created")
	
	-- Connect game over event
	gameOverConn = coreHealth.Destroyed:Connect(function()
		-- Disconnect immediately to prevent multiple fires
		if gameOverConn then
			gameOverConn:Disconnect()
			gameOverConn = nil
		end
		
		local currentWave = waveManager:GetCurrentWave()
		print("═══════════════════════════════")
		print("        GAME OVER")
		print("   Base Core Destroyed!")
		print("   Survived", currentWave, "waves")
		print("═══════════════════════════════")
		
		-- Stop and cleanup all systems
		StopRun()
	end)
	
	-- Start the game
	print("═══════════════════════════════")
	print("  Starting Zombie Defense!")
	print("═══════════════════════════════")
	waveManager:Start()
	print("✓ Game started - Wave 1 beginning!")
end

-- Create RemoteEvents for building system
local buildRemotesFolder = ReplicatedStorage:FindFirstChild("BuildRemotes")
if not buildRemotesFolder then
	buildRemotesFolder = Instance.new("Folder")
	buildRemotesFolder.Name = "BuildRemotes"
	buildRemotesFolder.Parent = ReplicatedStorage
end

local placeStructureRemote = buildRemotesFolder:FindFirstChild("PlaceStructure")
if not placeStructureRemote then
	placeStructureRemote = Instance.new("RemoteEvent")
	placeStructureRemote.Name = "PlaceStructure"
	placeStructureRemote.Parent = buildRemotesFolder
end

local deleteStructureRemote = buildRemotesFolder:FindFirstChild("DeleteStructure")
if not deleteStructureRemote then
	deleteStructureRemote = Instance.new("RemoteEvent")
	deleteStructureRemote.Name = "DeleteStructure"
	deleteStructureRemote.Parent = buildRemotesFolder
end

print("✓ Created BuildRemotes in ReplicatedStorage")

-- Handle structure placement
placeStructureRemote.OnServerEvent:Connect(function(player, structureType, position, rotation)
	if not buildService then
		warn("[BuildService] Service not initialized")
		return
	end
	
	-- Validate inputs
	if typeof(structureType) ~= "string" or typeof(position) ~= "Vector3" or typeof(rotation) ~= "number" then
		warn("[BuildService] Invalid parameters from", player.Name)
		return
	end
	
	local success, part, err
	
	if structureType == "floor" then
		success, part, err = buildService:PlaceFloor(player, position, rotation)
	elseif structureType == "wall" then
		success, part, err = buildService:PlaceWall(player, position, rotation)
	elseif structureType == "trap" then
		-- Find floor at position
		local floor = buildService:GetFloorAtPosition(position)
		if floor then
			success, part, err = buildService:PlaceFloorTrap(player, floor, "spike")
		else
			success, part, err = false, nil, "No floor found at this location"
		end
	elseif structureType == "ramp" then
		success, part, err = buildService:PlaceRamp(player, position, rotation)
	elseif structureType == "ceiling" then
		success, part, err = buildService:PlaceCeiling(player, position, rotation)
	else
		warn("[BuildService] Unknown structure type:", structureType)
		return
	end
	
	if not success then
		warn("[BuildService]", player.Name, "failed to place", structureType .. ":", err)
	end
end)

-- Handle structure deletion
deleteStructureRemote.OnServerEvent:Connect(function(player, part)
	if not buildService then
		warn("[BuildService] Service not initialized")
		return
	end
	
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		warn("[BuildService] Invalid part from", player.Name)
		return
	end
	
	local success, err = buildService:DeleteStructure(player, part)
	
	if not success then
		warn("[BuildService]", player.Name, "failed to delete structure:", err)
	end
end)

-- Create RemoteEvent for chat commands (kept for !restart command only)
local chatCommandRemote = ReplicatedStorage:FindFirstChild("ChatCommand")
if not chatCommandRemote then
	chatCommandRemote = Instance.new("RemoteEvent")
	chatCommandRemote.Name = "ChatCommand"
	chatCommandRemote.Parent = ReplicatedStorage
	print("✓ Created ChatCommand RemoteEvent in ReplicatedStorage")
end

-- Track first player for restart command
local firstPlayer = nil

-- Listen for first player to join
Players.PlayerAdded:Connect(function(player)
	if #Players:GetPlayers() == 1 then
		firstPlayer = player
		print("✓ Building system enabled for all players")
		print("✓ Restart command enabled for", player.Name)
		print("  - Use the hotbar at the bottom of the screen to build")
		print("  - Press 1, 2, 3 for Floor, Wall, Trap")
		print("  - Press R to rotate placement")
		print("  - Click delete button to remove structures")
		print("  - Type '!restart' to restart the game")
	end
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	if player == firstPlayer then
		firstPlayer = nil
	end
end)

-- Listen for chat commands via RemoteEvent (only !restart now)
chatCommandRemote.OnServerEvent:Connect(function(player, message)
	-- Only process commands from first player
	if player ~= firstPlayer then
		return
	end
	
	-- Validate message is a string
	if typeof(message) ~= "string" then
		return
	end
	
	-- Check if message starts with !
	if not message:match("^!") then
		return
	end
	
	if message == "!restart" then
		print("═══════════════════════════════")
		print("  Restarting game...")
		print("═══════════════════════════════")
		StopRun()
		task.wait(1) -- Brief delay for cleanup
		StartRun()
	end
end)

-- Start initial game run
StartRun()
