--[[
	BaseCoreHealth.lua
	Manages health and damage logic for the Base Core in Zombie Defense.
	
	Usage:
		local BaseCoreHealth = require(...)
		local core = BaseCoreHealth.new(baseCorePart, {
			maxHealth = 1000,
			clampDamage = true
		})
		
		core:Damage(50, zombieInstance)
		core:Heal(25)
		
		core.Destroyed:Connect(function()
			print("Base Core destroyed!")
		end)
]]

local RunService = game:GetService("RunService")

local BaseCoreHealth = {}
BaseCoreHealth.__index = BaseCoreHealth

-- Default configuration
local DEFAULT_CONFIG = {
	maxHealth = 1000,
	clampDamage = true
}

-- Constructor: Create a new Base Core health manager
function BaseCoreHealth.new(baseCorePart, config)
	assert(typeof(baseCorePart) == "Instance" and baseCorePart:IsA("BasePart"), "baseCorePart must be a BasePart")
	assert(RunService:IsServer(), "BaseCoreHealth must run on the server")
	
	local self = setmetatable({}, BaseCoreHealth)
	
	-- Merge config with defaults
	self.config = {}
	for key, value in pairs(DEFAULT_CONFIG) do
		self.config[key] = value
	end
	if config then
		for key, value in pairs(config) do
			self.config[key] = value
		end
	end
	
	-- Core properties
	self.baseCorePart = baseCorePart
	self.maxHealth = self.config.maxHealth
	self.currentHealth = self.maxHealth
	self.isDestroyed = false
	
	-- Create Destroyed event
	self.Destroyed = Instance.new("BindableEvent")
	
	-- Set debug attributes on the part
	self.baseCorePart:SetAttribute("Health", self.currentHealth)
	self.baseCorePart:SetAttribute("MaxHealth", self.maxHealth)
	
	return self
end

-- Apply damage to the Base Core
function BaseCoreHealth:Damage(amount, source)
	if self.isDestroyed then
		return
	end
	
	assert(typeof(amount) == "number" and amount >= 0, "Damage amount must be a non-negative number")
	
	-- Clamp damage if configured
	if self.config.clampDamage then
		amount = math.min(amount, self.currentHealth)
	end
	
	self.currentHealth = self.currentHealth - amount
	
	-- Clamp to 0 minimum
	if self.currentHealth < 0 then
		self.currentHealth = 0
	end
	
	-- Update debug attribute
	self.baseCorePart:SetAttribute("Health", self.currentHealth)
	
	-- Check if destroyed
	if self.currentHealth <= 0 and not self.isDestroyed then
		self.isDestroyed = true
		self.Destroyed:Fire()
	end
end

-- Heal the Base Core
function BaseCoreHealth:Heal(amount)
	if self.isDestroyed then
		return
	end
	
	assert(typeof(amount) == "number" and amount >= 0, "Heal amount must be a non-negative number")
	
	self.currentHealth = self.currentHealth + amount
	
	-- Clamp to max health if configured
	if self.config.clampDamage then
		self.currentHealth = math.min(self.currentHealth, self.maxHealth)
	end
	
	-- Update debug attribute
	self.baseCorePart:SetAttribute("Health", self.currentHealth)
end

-- Get current health
function BaseCoreHealth:GetHealth()
	return self.currentHealth
end

-- Get maximum health
function BaseCoreHealth:GetMaxHealth()
	return self.maxHealth
end

-- Check if Base Core is destroyed
function BaseCoreHealth:IsDestroyed()
	return self.isDestroyed
end

-- Cleanup: Disconnect and destroy resources
function BaseCoreHealth:Destroy()
	if self.Destroyed then
		self.Destroyed:Destroy()
		self.Destroyed = nil
	end
	
	self.baseCorePart = nil
	self.isDestroyed = true
end

return BaseCoreHealth
