-- GameInit.server.lua
-- Zombie Defense MVP integration script (restart-safe)
-- Initializes all game systems and starts the wave manager

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Load modules
local DamageService = require(ServerScriptService.Modules.DamageService)
local BaseCoreHealth = require(ServerScriptService.Modules.BaseCoreHealth)
local WaveManager = require(ServerScriptService.Modules.WaveManager)
local StructureHealthService = require(ServerScriptService.Modules.StructureHealthService)
local StructureSpawner = require(ServerScriptService.Modules.StructureSpawner)

-- Game state
local coreHealth = nil
local structureHealth = nil
local waveManager = nil
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

-- Studio-only testing commands
-- Listen for first player to join and allow commands via chat
Players.PlayerAdded:Connect(function(player)
	-- Only listen to the first player (for testing)
	if #Players:GetPlayers() == 1 then
		-- Per-player rotation state for spawning
		local rotationY = 0
		
		player.Chatted:Connect(function(message)
			if message == "!restart" then
				print("═══════════════════════════════")
				print("  Restarting game...")
				print("═══════════════════════════════")
				StopRun()
				task.wait(1) -- Brief delay for cleanup
				StartRun()
				
			elseif message == "!wall" then
				-- Spawn a wall in front of the player
				local character = player.Character
				if not character then
					print("⚠ Cannot spawn wall: character not found")
					return
				end
				
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then
					print("⚠ Cannot spawn wall: HumanoidRootPart not found")
					return
				end
				
				-- Position 12 studs in front of player
				local lookVector = hrp.CFrame.LookVector
				local spawnPosition = hrp.Position + (lookVector * 12)
				
				local wall = StructureSpawner.SpawnWall(spawnPosition, rotationY)
				print("✓ Spawned wall at", spawnPosition, "with rotation", rotationY)
				
			elseif message == "!floor" then
				-- Spawn a floor under the player
				local character = player.Character
				if not character then
					print("⚠ Cannot spawn floor: character not found")
					return
				end
				
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then
					print("⚠ Cannot spawn floor: HumanoidRootPart not found")
					return
				end
				
				-- Position at ground level (Y=0), using player's X/Z
				local spawnPosition = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
				
				local floor = StructureSpawner.SpawnFloor(spawnPosition, rotationY)
				print("✓ Spawned floor at", spawnPosition, "with rotation", rotationY)
				
			elseif message == "!rot90" then
				-- Toggle rotation between 0 and 90 degrees
				rotationY = (rotationY == 0) and 90 or 0
				print("✓ Rotation set to", rotationY, "degrees for next spawns")
			end
		end)
		print("✓ Testing commands enabled:")
		print("  - Type '!restart' to restart the game")
		print("  - Type '!wall' to spawn a wall in front of you")
		print("  - Type '!floor' to spawn a floor at your position")
		print("  - Type '!rot90' to toggle rotation (0° or 90°)")
	end
end)

-- Start initial game run
StartRun()
