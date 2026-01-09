--[[
	WaveManager.lua
	Controls the core game loop for Zombie Defense:
	- Manages wave progression
	- Spawns zombies with scaled stats
	- Tracks active zombies
	- Ends run when Base Core is destroyed
	
	Usage:
		local WaveManager = require(...)
		local manager = WaveManager.new({
			baseCoreHealth = coreHealthInstance,
			zombieTemplate = zombieModel,
			spawnPoints = {spawnPart1, spawnPart2},
			damageService = DamageService
		})
		manager:Start()
--]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local ZombieAI = require(script.Parent.ZombieAI)

local WaveManager = {}
WaveManager.__index = WaveManager

-- Default configuration
local DEFAULT_CONFIG = {
	zombiesPerWave = 5,
	zombieIncrementPerWave = 3,
	timeBetweenWaves = 10,
	zombieSpawnDelay = 0.3,
	
	zombieStats = {
		baseHealth = 100,
		baseDamage = 10,
		baseSpeed = 16,
		
		healthScalePerWave = 0.15,
		damageScalePerWave = 0.10,
		speedScalePerWave = 0.03,
	}
}

function WaveManager.new(config)
	assert(RunService:IsServer(), "WaveManager must run on the server")
	assert(config, "Config is required")
	assert(config.baseCoreHealth, "baseCoreHealth is required")
	assert(config.zombieTemplate, "zombieTemplate is required")
	assert(config.spawnPoints and #config.spawnPoints > 0, "spawnPoints is required and must not be empty")
	assert(config.damageService, "damageService is required")
	
	local self = setmetatable({}, WaveManager)
	
	-- Required config
	self.baseCoreHealth = config.baseCoreHealth
	self.zombieTemplate = config.zombieTemplate
	self.spawnPoints = config.spawnPoints
	self.damageService = config.damageService
	
	-- Optional config with defaults
	self.zombiesPerWave = config.zombiesPerWave or DEFAULT_CONFIG.zombiesPerWave
	self.zombieIncrementPerWave = config.zombieIncrementPerWave or DEFAULT_CONFIG.zombieIncrementPerWave
	self.timeBetweenWaves = config.timeBetweenWaves or DEFAULT_CONFIG.timeBetweenWaves
	self.zombieSpawnDelay = config.zombieSpawnDelay or DEFAULT_CONFIG.zombieSpawnDelay
	
	-- Zombie stats
	self.zombieStats = {}
	for key, value in pairs(DEFAULT_CONFIG.zombieStats) do
		self.zombieStats[key] = (config.zombieStats and config.zombieStats[key]) or value
	end
	
	-- State
	self.currentWave = 0
	self.isRunning = false
	self.activeZombies = {}
	self.baseCoreDestroyed = false
	
	-- Connect to Base Core destruction
	self.destroyedConnection = self.baseCoreHealth.Destroyed:Connect(function()
		self.baseCoreDestroyed = true
		self:Stop()
	end)
	
	return self
end

-- Calculate zombie stats for a given wave
function WaveManager:CalculateZombieStats(wave)
	local stats = self.zombieStats
	local waveMultiplier = wave - 1 -- Wave 1 = base stats
	
	return {
		health = stats.baseHealth * (1 + waveMultiplier * stats.healthScalePerWave),
		damage = stats.baseDamage * (1 + waveMultiplier * stats.damageScalePerWave),
		speed = stats.baseSpeed * (1 + waveMultiplier * stats.speedScalePerWave),
	}
end

-- Spawn a single zombie
function WaveManager:SpawnZombie(wave)
	-- Pick random spawn point
	local spawnPoint = self.spawnPoints[math.random(1, #self.spawnPoints)]
	
	-- Clone zombie
	local zombie = self.zombieTemplate:Clone()
	zombie.Parent = workspace
	
	-- Position zombie at spawn point
	local rootPart = zombie:FindFirstChild("HumanoidRootPart") or zombie.PrimaryPart
	if rootPart then
		rootPart.CFrame = spawnPoint.CFrame + Vector3.new(
			math.random(-3, 3),
			0,
			math.random(-3, 3)
		)
	end
	
	-- Calculate stats for this wave
	local stats = self:CalculateZombieStats(wave)
	
	-- Apply health to humanoid
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = stats.health
		humanoid.Health = stats.health
		humanoid.WalkSpeed = stats.speed
	end
	
	-- Find base core part (assume it's the part the health is attached to)
	local baseCorePart = self.baseCoreHealth.baseCorePart
	
	-- Create ZombieAI
	local zombieAI = ZombieAI.new(zombie, baseCorePart, {
		damage = stats.damage,
		moveSpeed = stats.speed,
		damageTarget = function(target, amount)
			return self.damageService.Damage(target, amount, zombie)
		end
	})
	
	zombieAI:Start()
	
	-- Track zombie
	table.insert(self.activeZombies, {
		model = zombie,
		ai = zombieAI
	})
	
	-- Clean up when zombie dies
	if humanoid then
		humanoid.Died:Connect(function()
			self:RemoveZombie(zombie)
		end)
	end
end

-- Remove zombie from tracking
function WaveManager:RemoveZombie(zombieModel)
	for i, zombieData in ipairs(self.activeZombies) do
		if zombieData.model == zombieModel then
			-- Stop AI
			if zombieData.ai then
				zombieData.ai:Stop()
			end
			-- Remove from tracking
			table.remove(self.activeZombies, i)
			-- Destroy model
			if zombieModel.Parent then
				zombieModel:Destroy()
			end
			break
		end
	end
end

-- Check if all zombies are dead
function WaveManager:AreAllZombiesDead()
	return #self.activeZombies == 0
end

-- Run a single wave
function WaveManager:RunWave()
	self.currentWave = self.currentWave + 1
	local wave = self.currentWave
	
	print("[WaveManager] Starting wave", wave)
	
	-- Calculate zombie count
	local zombieCount = self.zombiesPerWave + (wave - 1) * self.zombieIncrementPerWave
	
	-- Spawn zombies one by one
	for i = 1, zombieCount do
		if not self.isRunning then break end
		
		self:SpawnZombie(wave)
		
		if i < zombieCount then
			task.wait(self.zombieSpawnDelay)
		end
	end
	
	print("[WaveManager] Spawned", zombieCount, "zombies for wave", wave)
	
	-- Wait for all zombies to die or game to stop
	while self.isRunning and not self:AreAllZombiesDead() do
		task.wait(1)
	end
	
	if not self.isRunning then
		return false -- Game stopped
	end
	
	print("[WaveManager] Wave", wave, "completed")
	
	-- Wait between waves
	print("[WaveManager] Next wave in", self.timeBetweenWaves, "seconds")
	task.wait(self.timeBetweenWaves)
	
	return true -- Continue to next wave
end

-- Start the wave manager
function WaveManager:Start()
	assert(RunService:IsServer(), "WaveManager must run on the server")
	
	if self.isRunning then
		warn("[WaveManager] Already running")
		return
	end
	
	self.isRunning = true
	self.currentWave = 0
	self.baseCoreDestroyed = false
	
	print("[WaveManager] Starting game loop")
	
	-- Run waves in a loop
	task.spawn(function()
		while self.isRunning do
			local continue = self:RunWave()
			if not continue then
				break
			end
		end
		
		-- Game ended
		if self.baseCoreDestroyed then
			print("[WaveManager] Game Over - Base Core destroyed at wave", self.currentWave)
		else
			print("[WaveManager] Game stopped at wave", self.currentWave)
		end
	end)
end

-- Stop the wave manager
function WaveManager:Stop()
	if not self.isRunning then
		return
	end
	
	print("[WaveManager] Stopping game loop")
	self.isRunning = false
	
	-- Stop and clean up all active zombies
	for _, zombieData in ipairs(self.activeZombies) do
		if zombieData.ai then
			zombieData.ai:Stop()
		end
		if zombieData.model and zombieData.model.Parent then
			zombieData.model:Destroy()
		end
	end
	
	self.activeZombies = {}
end

-- Get current wave number
function WaveManager:GetCurrentWave()
	return self.currentWave
end

-- Check if running
function WaveManager:IsRunning()
	return self.isRunning
end

-- Cleanup (call when done with manager)
function WaveManager:Destroy()
	self:Stop()
	
	if self.destroyedConnection then
		self.destroyedConnection:Disconnect()
		self.destroyedConnection = nil
	end
end

return WaveManager
