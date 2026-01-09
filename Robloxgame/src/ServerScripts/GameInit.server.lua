-- GameInit.server.lua
-- Zombie Defense MVP integration script
-- Initializes all game systems and starts the wave manager

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Load modules
local DamageService = require(ServerScriptService.Modules.DamageService)
local BaseCoreHealth = require(ServerScriptService.Modules.BaseCoreHealth)
local WaveManager = require(ServerScriptService.Modules.WaveManager)
local StructureHealthService = require(ServerScriptService.Modules.StructureHealthService)

-- Find required objects
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

-- Create Base Core health system
local coreHealth = BaseCoreHealth.new(baseCorePart, {
	maxHealth = 1000,
	clampDamage = true
})

print("✓ Base Core Health initialized with", coreHealth:GetMaxHealth(), "HP")

-- Register Base Core with damage service
DamageService.RegisterBaseCore(baseCorePart, coreHealth)
print("✓ Base Core registered with DamageService")

-- Create structure health service
local structureHealth = StructureHealthService.new({
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
local waveManager = WaveManager.new({
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
coreHealth.Destroyed:Connect(function()
	local currentWave = waveManager:GetCurrentWave()
	print("═══════════════════════════════")
	print("        GAME OVER")
	print("   Base Core Destroyed!")
	print("   Survived", currentWave, "waves")
	print("═══════════════════════════════")
	
	-- Stop wave manager
	waveManager:Stop()
	
	-- Cleanup structure health service
	structureHealth:Destroy()
end)

-- Start the game
print("═══════════════════════════════")
print("  Starting Zombie Defense!")
print("═══════════════════════════════")
waveManager:Start()
print("✓ Game started - Wave 1 beginning!")
