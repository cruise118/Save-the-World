--[[
	TrapService.lua
	Manages traps that damage zombies when triggered
	
	Integration:
		local TrapService = require(game.ServerScriptService.Modules.TrapService)
		local traps = TrapService.new({ spikeDamage = 15, hitCooldown = 0.75, debug = false })
		traps:RegisterSpikeTrap(trapPart)
--]]

local RunService = game:GetService("RunService")

local TrapService = {}
TrapService.__index = TrapService

-- Create a new TrapService instance
function TrapService.new(config)
	assert(RunService:IsServer(), "TrapService must run on the server")
	
	local self = setmetatable({}, TrapService)
	
	-- Config with defaults
	self.config = {
		spikeDamage = 15,
		hitCooldown = 0.75,
		debug = false,
	}
	
	if config then
		for k, v in pairs(config) do
			self.config[k] = v
		end
	end
	
	-- Trap tracking
	self.traps = {} -- { [trapId] = { part, connection, cooldowns, type } }
	self.nextTrapId = 1
	
	return self
end

-- Find zombie model from a part (traverse ancestry)
local function FindZombieFromPart(part)
	local current = part
	while current and current ~= workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			local rootPart = current:FindFirstChild("HumanoidRootPart")
			if humanoid and rootPart then
				return current, humanoid
			end
		end
		current = current.Parent
	end
	return nil, nil
end

-- Register a spike trap
function TrapService:RegisterSpikeTrap(trapPart, config)
	assert(RunService:IsServer(), "RegisterSpikeTrap must run on the server")
	assert(typeof(trapPart) == "Instance" and trapPart:IsA("BasePart"), "trapPart must be a BasePart")
	
	-- Generate trap ID
	local trapId = self.nextTrapId
	self.nextTrapId = self.nextTrapId + 1
	
	-- Per-zombie cooldown tracking for this trap
	local zombieCooldowns = {} -- { [zombie] = lastHitTime }
	
	-- Touch handler
	local function OnTouched(otherPart)
		if not trapPart.Parent then
			return -- Trap was destroyed
		end
		
		-- Find zombie from touching part
		local zombieModel, humanoid = FindZombieFromPart(otherPart)
		if not zombieModel or not humanoid then
			return -- Not a zombie
		end
		
		if humanoid.Health <= 0 then
			return -- Already dead
		end
		
		-- Check cooldown
		local now = time()
		local lastHit = zombieCooldowns[zombieModel]
		if lastHit and (now - lastHit) < self.config.hitCooldown then
			return -- Still on cooldown
		end
		
		-- Apply damage
		humanoid:TakeDamage(self.config.spikeDamage)
		zombieCooldowns[zombieModel] = now
		
		if self.config.debug then
			print("[TrapService] Spike trap damaged zombie:", zombieModel.Name, "for", self.config.spikeDamage, "damage")
		end
	end
	
	-- Connect touch event
	local connection = trapPart.Touched:Connect(OnTouched)
	
	-- Auto-unregister if trap part is removed
	local ancestryConnection = trapPart.AncestryChanged:Connect(function()
		if not trapPart:IsDescendantOf(game) then
			self:Unregister(trapId)
		end
	end)
	
	-- Store trap data
	self.traps[trapId] = {
		part = trapPart,
		connection = connection,
		ancestryConnection = ancestryConnection,
		cooldowns = zombieCooldowns,
		trapType = "spike",
	}
	
	if self.config.debug then
		print("[TrapService] Registered spike trap:", trapPart.Name, "with ID:", trapId)
	end
	
	return trapId
end

-- Unregister a trap
function TrapService:Unregister(trapId)
	assert(RunService:IsServer(), "Unregister must run on the server")
	
	local trap = self.traps[trapId]
	if not trap then
		return
	end
	
	-- Disconnect connections
	if trap.connection then
		trap.connection:Disconnect()
	end
	if trap.ancestryConnection then
		trap.ancestryConnection:Disconnect()
	end
	
	-- Clear cooldowns
	if trap.cooldowns then
		table.clear(trap.cooldowns)
	end
	
	-- Remove from tracking
	self.traps[trapId] = nil
	
	if self.config.debug then
		print("[TrapService] Unregistered trap ID:", trapId)
	end
end

-- Cleanup all traps
function TrapService:Destroy()
	assert(RunService:IsServer(), "Destroy must run on the server")
	
	-- Unregister all traps
	for trapId, _ in pairs(self.traps) do
		self:Unregister(trapId)
	end
	
	if self.config.debug then
		print("[TrapService] Destroyed all traps")
	end
end

return TrapService
