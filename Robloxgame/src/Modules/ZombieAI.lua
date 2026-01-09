--[[
	ZombieAI Module - MVP Implementation
	
	Controls a single zombie NPC using a simple state machine.
	States: Idle, MoveToTarget, Attack, Dead
	
	Usage:
		local ZombieAI = require(script.Parent.ZombieAI)
		local zombie = ZombieAI.new(zombieModel, baseCoreTarget, config)
		zombie:Start()
		-- zombie:Stop() when done
]]

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local ZombieAI = {}
ZombieAI.__index = ZombieAI

-- Default configuration
local DEFAULT_CONFIG = {
	-- Combat stats
	damage = 10,
	attackCooldown = 1.0,
	attackRange = 6,
	
	-- Detection
	structureDetectionRange = 18,
	
	-- Movement
	moveSpeed = 16,
	pathfindingUpdateInterval = 1.0,
	
	-- Callbacks
	damageTarget = nil, -- function(target: Instance, amount: number)
}

-- State enum
local State = {
	Idle = "Idle",
	MoveToTarget = "MoveToTarget",
	Attack = "Attack",
	Dead = "Dead",
}

--[[
	Creates a new ZombieAI instance
	
	@param model - The zombie's character model (Model with Humanoid)
	@param baseCore - The Base Core part to target (BasePart)
	@param config - Optional configuration table (see DEFAULT_CONFIG)
	@return ZombieAI instance
]]
function ZombieAI.new(model, baseCore, config)
	local self = setmetatable({}, ZombieAI)
	
	-- Validate inputs
	assert(model and model:IsA("Model"), "ZombieAI: model must be a Model")
	assert(baseCore and baseCore:IsA("BasePart"), "ZombieAI: baseCore must be a BasePart")
	
	self.model = model
	self.humanoid = model:FindFirstChildOfClass("Humanoid")
	self.rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	self.baseCore = baseCore
	
	assert(self.humanoid, "ZombieAI: model must have a Humanoid")
	assert(self.rootPart, "ZombieAI: model must have a HumanoidRootPart or PrimaryPart")
	
	-- Merge config with defaults
	self.config = {}
	for key, value in pairs(DEFAULT_CONFIG) do
		self.config[key] = if config and config[key] ~= nil then config[key] else value
	end
	
	-- Validate damageTarget if provided
	if self.config.damageTarget ~= nil then
		assert(typeof(self.config.damageTarget) == "function", "damageTarget must be a function")
	end
	
	-- State management
	self.state = State.Idle
	self.currentTarget = nil -- Current structure or base core being targeted
	
	-- Timers
	self.lastAttackTime = 0
	self.lastPathUpdateTime = 0
	
	-- Pathfinding
	self.currentPath = nil
	self.currentWaypoint = 1
	
	-- Connection tracking
	self.connections = {}
	self.isActive = false
	
	return self
end

--[[
	Starts the zombie AI behavior
]]
function ZombieAI:Start()
	assert(RunService:IsServer(), "ZombieAI must run on the server")
	
	if self.isActive then
		return
	end
	
	self.isActive = true
	self.state = State.Idle
	
	-- Set humanoid properties
	self.humanoid.WalkSpeed = self.config.moveSpeed
	
	-- Connect to humanoid death
	table.insert(self.connections, self.humanoid.Died:Connect(function()
		self:SetState(State.Dead)
		self:Stop()
	end))
	
	-- Main update loop using task.spawn
	task.spawn(function()
		while self.isActive do
			self:Update()
			task.wait(0.1)
		end
	end)
	
	print(string.format("ZombieAI: Started for %s", self.model.Name))
end

--[[
	Stops the zombie AI and cleans up connections
]]
function ZombieAI:Stop()
	self.isActive = false
	
	-- Disconnect all connections
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	
	print(string.format("ZombieAI: Stopped for %s", self.model.Name))
end

--[[
	Main update loop - called periodically
]]
function ZombieAI:Update()
	if not self.isActive or self.state == State.Dead then
		return
	end
	
	-- Validate zombie is still alive
	if self.humanoid.Health <= 0 then
		self:SetState(State.Dead)
		return
	end
	
	-- State machine
	if self.state == State.Idle then
		self:UpdateIdle()
	elseif self.state == State.MoveToTarget then
		self:UpdateMove()
	elseif self.state == State.Attack then
		self:UpdateAttack()
	end
end

--[[
	Idle state: Find a target and transition to move
]]
function ZombieAI:UpdateIdle()
	-- Find nearest structure or use base core
	local target = self:FindNearestStructure()
	if not target then
		target = self.baseCore
	end
	
	self.currentTarget = target
	self:SetState(State.MoveToTarget)
end

--[[
	Move state: Pathfind toward current target
]]
function ZombieAI:UpdateMove()
	-- Check if we should update target
	local nearestStructure = self:FindNearestStructure()
	if nearestStructure and nearestStructure ~= self.currentTarget then
		self.currentTarget = nearestStructure
		self.currentPath = nil -- Force path recalculation
	end
	
	-- Validate target still exists
	if not self.currentTarget or not self.currentTarget.Parent then
		self.currentTarget = self.baseCore
	end
	
	-- Check if in attack range
	local distanceToTarget = (self.rootPart.Position - self.currentTarget.Position).Magnitude
	if distanceToTarget <= self.config.attackRange then
		self:SetState(State.Attack)
		return
	end
	
	-- Update pathfinding
	local currentTime = time()
	if not self.currentPath or (currentTime - self.lastPathUpdateTime) >= self.config.pathfindingUpdateInterval then
		self:CalculatePath(self.currentTarget.Position)
		self.lastPathUpdateTime = currentTime
	end
	
	-- Follow path
	if self.currentPath and self.currentWaypoint <= #self.currentPath then
		local waypoint = self.currentPath[self.currentWaypoint]
		self.humanoid:MoveTo(waypoint)
		
		-- Check if reached waypoint
		local distanceToWaypoint = (self.rootPart.Position - waypoint).Magnitude
		if distanceToWaypoint < 3 then
			self.currentWaypoint = self.currentWaypoint + 1
		end
	else
		-- No valid path, move directly
		self.humanoid:MoveTo(self.currentTarget.Position)
	end
end

--[[
	Attack state: Damage target at intervals
]]
function ZombieAI:UpdateAttack()
	-- Validate target still exists
	if not self.currentTarget or not self.currentTarget.Parent then
		self:SetState(State.Idle)
		return
	end
	
	-- Check if still in range
	local distanceToTarget = (self.rootPart.Position - self.currentTarget.Position).Magnitude
	if distanceToTarget > self.config.attackRange then
		self:SetState(State.MoveToTarget)
		return
	end
	
	-- Attack on cooldown
	local currentTime = time()
	if (currentTime - self.lastAttackTime) >= self.config.attackCooldown then
		self:PerformAttack(self.currentTarget)
		self.lastAttackTime = currentTime
	end
	
	-- Face the target
	local direction = (self.currentTarget.Position - self.rootPart.Position) * Vector3.new(1, 0, 1)
	if direction.Magnitude > 0 then
		self.rootPart.CFrame = CFrame.new(self.rootPart.Position, self.rootPart.Position + direction)
	end
end

--[[
	Performs an attack on the target
]]
function ZombieAI:PerformAttack(target)
	-- Call damage callback if provided
	if self.config.damageTarget then
		self.config.damageTarget(target, self.config.damage)
	else
		-- Default behavior: just print
		warn(string.format("ZombieAI: No damageTarget callback set. Would deal %d damage to %s", 
			self.config.damage, target.Name))
	end
end

--[[
	Finds the nearest player-built structure within detection range
	@return BasePart or nil
]]
function ZombieAI:FindNearestStructure()
	local structures = CollectionService:GetTagged("Structure")
	local nearestStructure = nil
	local nearestDistance = self.config.structureDetectionRange
	
	for _, structure in ipairs(structures) do
		if structure:IsA("BasePart") and structure.Parent then
			local distance = (self.rootPart.Position - structure.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestStructure = structure
			end
		end
	end
	
	return nearestStructure
end

--[[
	Calculates a path to the target position using PathfindingService
]]
function ZombieAI:CalculatePath(targetPosition)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4,
		Costs = {
			Water = math.huge,
		}
	})
	
	local success, errorMessage = pcall(function()
		path:ComputeAsync(self.rootPart.Position, targetPosition)
	end)
	
	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		
		-- Convert waypoints to Vector3 positions
		self.currentPath = {}
		for _, waypoint in ipairs(waypoints) do
			table.insert(self.currentPath, waypoint.Position)
		end
		
		-- Reset waypoint index on new path
		self.currentWaypoint = 1
	else
		-- Path failed, clear path and move directly
		self.currentPath = nil
		self.currentWaypoint = 1
		if errorMessage then
			warn(string.format("ZombieAI: Pathfinding failed for %s: %s", self.model.Name, errorMessage))
		end
	end
end

--[[
	Changes the zombie's state
]]
function ZombieAI:SetState(newState)
	if self.state == newState then
		return
	end
	
	-- State exit logic
	if self.state == State.MoveToTarget then
		self.humanoid:MoveTo(self.rootPart.Position) -- Stop moving
	end
	
	self.state = newState
	
	-- State enter logic
	if newState == State.Dead then
		self.humanoid:MoveTo(self.rootPart.Position)
	end
end

--[[
	Gets the current state of the zombie
	@return string - Current state name
]]
function ZombieAI:GetState()
	return self.state
end

--[[
	Checks if the zombie is alive
	@return boolean
]]
function ZombieAI:IsAlive()
	return self.state ~= State.Dead and self.humanoid.Health > 0
end

return ZombieAI
