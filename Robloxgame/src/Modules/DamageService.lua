--[[
	DamageService.lua
	
	Centralizes all damage routing for the Zombie Defense game.
	Routes damage to Base Core or Structures based on target type.
	
	Usage:
		local DamageService = require(game.ServerScriptService.Modules.DamageService)
		
		-- Register base core
		DamageService.RegisterBaseCore(baseCorePart, baseCoreHealthInstance)
		
		-- Set structure damage handler
		DamageService.SetStructureDamageHandler(function(structurePart, amount, source)
			-- Handle structure damage
		end)
		
		-- Use in ZombieAI config:
		damageTarget = function(t, a) 
			DamageService.Damage(t, a, zombieModel) 
		end
--]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DamageService = {}

-- Private state
local registeredBaseCores = {} -- [BasePart] = BaseCoreHealth instance
local structureDamageHandler = nil
local warningCache = {} -- [target] = true (to prevent warning spam)

--[[
	Register a Base Core part with its health instance
	@param baseCorePart BasePart - The base core part
	@param baseCoreHealthInstance - The BaseCoreHealth instance
--]]
function DamageService.RegisterBaseCore(baseCorePart, baseCoreHealthInstance)
	assert(RunService:IsServer(), "DamageService must run on the server")
	assert(baseCorePart and baseCorePart:IsA("BasePart"), "baseCorePart must be a BasePart")
	assert(baseCoreHealthInstance, "baseCoreHealthInstance is required")
	assert(typeof(baseCoreHealthInstance.Damage) == "function", "baseCoreHealthInstance must have a Damage method")
	
	registeredBaseCores[baseCorePart] = baseCoreHealthInstance
end

--[[
	Unregister a Base Core part
	@param baseCorePart BasePart - The base core part
--]]
function DamageService.UnregisterBaseCore(baseCorePart)
	assert(RunService:IsServer(), "DamageService must run on the server")
	assert(baseCorePart, "baseCorePart is required")
	
	registeredBaseCores[baseCorePart] = nil
	warningCache[baseCorePart] = nil
end

--[[
	Set the structure damage handler function
	@param fn function(structurePart: BasePart, amount: number, source: any)
--]]
function DamageService.SetStructureDamageHandler(fn)
	assert(RunService:IsServer(), "DamageService must run on the server")
	assert(fn == nil or typeof(fn) == "function", "handler must be a function or nil")
	
	structureDamageHandler = fn
end

--[[
	Apply damage to a target
	@param target Instance - The target to damage
	@param amount number - The damage amount
	@param source any - Optional source of the damage (e.g., zombie model)
	@return boolean - True if damage was handled, false otherwise
--]]
function DamageService.Damage(target, amount, source)
	assert(RunService:IsServer(), "DamageService must run on the server")
	
	-- Validate inputs
	if not target or not target:IsDescendantOf(game) then
		return false
	end
	
	if typeof(amount) ~= "number" or amount <= 0 then
		return false
	end
	
	-- Route to registered base core
	if registeredBaseCores[target] then
		local baseCoreHealth = registeredBaseCores[target]
		-- Ensure the instance still exists and has the method
		if baseCoreHealth and typeof(baseCoreHealth.Damage) == "function" then
			baseCoreHealth:Damage(amount, source)
			return true
		else
			-- Clean up invalid registration
			registeredBaseCores[target] = nil
			return false
		end
	end
	
	-- Route to structure handler
	if target:IsA("BasePart") and CollectionService:HasTag(target, "Structure") then
		if structureDamageHandler then
			structureDamageHandler(target, amount, source)
			return true
		else
			-- Warn once per target to avoid spam
			if not warningCache[target] then
				warn(string.format(
					"DamageService: Structure '%s' was damaged but no handler is set",
					target:GetFullName()
				))
				warningCache[target] = true
			end
			return true
		end
	end
	
	-- Target is neither a base core nor a structure
	return false
end

return DamageService
