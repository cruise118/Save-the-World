--[[
	StructureHealthService.lua
	Manages HP for BaseParts tagged "Structure"
	
	Integration with DamageService:
	local structureHealth = StructureHealthService.new()
	DamageService.SetStructureDamageHandler(function(part, amount, source)
		structureHealth:Damage(part, amount, source)
	end)
]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local StructureHealthService = {}
StructureHealthService.__index = StructureHealthService

-- Default configuration
local DEFAULT_CONFIG = {
	defaultMaxHealth = 200,
	destroyDelay = 0.05,
	debug = false,
}

function StructureHealthService.new(config)
	assert(RunService:IsServer(), "StructureHealthService must run on the server")
	
	local self = setmetatable({}, StructureHealthService)
	
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
	
	-- Track registered structures
	self.registered = {} -- [part] = { connection: RBXScriptConnection }
	
	return self
end

-- Register a structure part and set default attributes if missing
function StructureHealthService:Register(part)
	assert(RunService:IsServer(), "Register must be called on the server")
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "part must be a BasePart")
	
	-- Already registered
	if self.registered[part] then
		return
	end
	
	-- Set default MaxHealth if missing
	if not part:GetAttribute("MaxHealth") then
		part:SetAttribute("MaxHealth", self.config.defaultMaxHealth)
	end
	
	-- Set Health to MaxHealth if missing
	if not part:GetAttribute("Health") then
		part:SetAttribute("Health", part:GetAttribute("MaxHealth"))
	end
	
	-- Mark as not destroyed
	if not part:GetAttribute("Destroyed") then
		part:SetAttribute("Destroyed", false)
	end
	
	-- Connect to AncestryChanged for auto-cleanup
	local connection = part.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:Unregister(part)
		end
	end)
	
	self.registered[part] = {
		connection = connection,
	}
	
	if self.config.debug then
		print("StructureHealthService: Registered", part.Name, "with", part:GetAttribute("MaxHealth"), "HP")
	end
end

-- Unregister a structure part
function StructureHealthService:Unregister(part)
	local data = self.registered[part]
	if not data then
		return
	end
	
	-- Disconnect connection
	if data.connection then
		data.connection:Disconnect()
	end
	
	self.registered[part] = nil
	
	if self.config.debug then
		print("StructureHealthService: Unregistered", part.Name)
	end
end

-- Apply damage to a structure
function StructureHealthService:Damage(part, amount, source)
	assert(RunService:IsServer(), "Damage must be called on the server")
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "part must be a BasePart")
	assert(type(amount) == "number" and amount > 0, "amount must be a positive number")
	
	-- Auto-register if tagged but not registered
	if not self.registered[part] and CollectionService:HasTag(part, "Structure") then
		self:Register(part)
	end
	
	-- Not a registered structure
	if not self.registered[part] then
		return false
	end
	
	-- Already destroyed
	if part:GetAttribute("Destroyed") then
		return false
	end
	
	local currentHealth = part:GetAttribute("Health") or 0
	local newHealth = math.max(0, currentHealth - amount)
	
	part:SetAttribute("Health", newHealth)
	
	-- Structure destroyed
	if newHealth <= 0 then
		part:SetAttribute("Destroyed", true)
		
		if self.config.debug then
			print("StructureHealthService: Destroyed", part.Name)
		end
		
		-- Destroy after delay
		task.delay(self.config.destroyDelay, function()
			if part and part.Parent then
				self:Unregister(part)
				part:Destroy()
			end
		end)
	end
	
	return true
end

-- Heal a structure
function StructureHealthService:Heal(part, amount)
	assert(RunService:IsServer(), "Heal must be called on the server")
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "part must be a BasePart")
	assert(type(amount) == "number" and amount > 0, "amount must be a positive number")
	
	-- Not a registered structure
	if not self.registered[part] then
		return false
	end
	
	-- Already destroyed
	if part:GetAttribute("Destroyed") then
		return false
	end
	
	local currentHealth = part:GetAttribute("Health") or 0
	local maxHealth = part:GetAttribute("MaxHealth") or self.config.defaultMaxHealth
	local newHealth = math.min(maxHealth, currentHealth + amount)
	
	part:SetAttribute("Health", newHealth)
	
	return true
end

-- Get current health of a structure
function StructureHealthService:GetHealth(part)
	if not self.registered[part] then
		return nil
	end
	
	return part:GetAttribute("Health")
end

-- Get max health of a structure
function StructureHealthService:GetMaxHealth(part)
	if not self.registered[part] then
		return nil
	end
	
	return part:GetAttribute("MaxHealth")
end

-- Check if a structure is destroyed
function StructureHealthService:IsDestroyed(part)
	if not self.registered[part] then
		return false
	end
	
	return part:GetAttribute("Destroyed") == true
end

-- Cleanup all connections and tracked structures
function StructureHealthService:Destroy()
	for part, data in pairs(self.registered) do
		if data.connection then
			data.connection:Disconnect()
		end
	end
	
	self.registered = {}
	
	if self.config.debug then
		print("StructureHealthService: Destroyed")
	end
end

return StructureHealthService
