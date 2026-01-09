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
local Players = game:GetService("Players")

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
	playerDetectionRange = 25,
	
	-- Movement
	moveSpeed = 14, -- Slower than default player speed (16)
	pathfindingUpdateInterval = 0.5, -- More frequent updates
	
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
	self._loopRunning = false
	
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
	
	-- Prevent multiple loops from starting
	if self._loopRunning then
		return
	end
	
	self.isActive = true
	self._loopRunning = true
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
		-- Initial delay to ensure model is fully loaded
		task.wait(0.1)
		
		-- Force initial idle update to get moving immediately
		if self.isActive then
			self:UpdateIdle()
		end
		
		while self.isActive do
			self:Update()
			task.wait(0.1)
		end
		-- Loop exited, clear flag
		self._loopRunning = false
	end)
	
	print(string.format("ZombieAI: Started for %s", self.model.Name))
end

--[[
	Stops the zombie AI and cleans up connections
]]
function ZombieAI:Stop()
	self.isActive = false
	self._loopRunning = false
	
	-- Halt movement
	if self.humanoid and self.humanoid.Parent and self.rootPart and self.rootPart.Parent then
		self.humanoid:MoveTo(self.rootPart.Position)
	end
	
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
	
	-- Safety checks: ensure model and rootPart still exist
	if not self.model.Parent or not self.rootPart.Parent then
		self:Stop()
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
	-- Check for nearby players first (highest priority)
	local nearestPlayer = self:FindNearestPlayer()
	if nearestPlayer then
		self.currentTarget = nearestPlayer
		self:SetState(State.MoveToTarget)
		return
	end
	
	-- Find nearest structure or use base core
	local target, _ = self:FindNearestStructure()
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
	-- Check for nearby players first (highest priority, overrides other targets)
	local nearestPlayer = self:FindNearestPlayer()
	if nearestPlayer then
		-- Player detected, switch target if different
		if self.currentTarget ~= nearestPlayer then
			self.currentTarget = nearestPlayer
			self.currentPath = nil -- Force path recalculation
		end
	else
		-- No player nearby, check structures or base core
		-- Validate current target still exists
		if not self.currentTarget or not self.currentTarget.Parent then
			self.currentTarget = self.baseCore
		end
		
		-- Check if we should update target (reduce jitter with threshold)
		local nearestStructure, nearestDistance = self:FindNearestStructure()
		if nearestStructure and nearestStructure ~= self.currentTarget then
			-- Only switch if meaningfully closer (20% threshold)
			local currentTargetDistance = (self.rootPart.Position - self.currentTarget.Position).Magnitude
			if nearestDistance < currentTargetDistance * 0.8 then
				self.currentTarget = nearestStructure
				self.currentPath = nil -- Force path recalculation
			end
		end
	end
	
	-- Get current target position (handle players vs parts)
	local targetPosition = self:GetTargetPosition(self.currentTarget)
	if not targetPosition then
		self:SetState(State.Idle)
		return
	end
	
	-- Check if in attack range
	local distanceToTarget = (self.rootPart.Position - targetPosition).Magnitude
	if distanceToTarget <= self.config.attackRange then
		self:SetState(State.Attack)
		return
	end
	
	-- Update pathfinding more frequently
	local currentTime = time()
	if not self.currentPath or (currentTime - self.lastPathUpdateTime) >= self.config.pathfindingUpdateInterval then
		self:CalculatePath(targetPosition)
		self.lastPathUpdateTime = currentTime
	end
	
	-- Follow path
	if self.currentPath and self.currentWaypoint <= #self.currentPath then
		local waypoint = self.currentPath[self.currentWaypoint]
		self.humanoid:MoveTo(waypoint)
		
		-- Check if reached waypoint
		local distanceToWaypoint = (self.rootPart.Position - waypoint).Magnitude
		if distanceToWaypoint < 4 then
			self.currentWaypoint = self.currentWaypoint + 1
		end
	else
		-- No valid path, move directly toward target
		self.humanoid:MoveTo(targetPosition)
	end
end

--[[
	Attack state: Damage target at intervals
]]
function ZombieAI:UpdateAttack()
	-- Get current target position
	local targetPosition = self:GetTargetPosition(self.currentTarget)
	if not targetPosition then
		self:SetState(State.Idle)
		return
	end
	
	-- Check if still in range
	local distanceToTarget = (self.rootPart.Position - targetPosition).Magnitude
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
	local direction = (targetPosition - self.rootPart.Position) * Vector3.new(1, 0, 1)
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
	Finds the nearest player within detection range
	@return Player or nil
]]
function ZombieAI:FindNearestPlayer()
	local players = Players:GetPlayers()
	local nearestPlayer = nil
	local nearestDistance = self.config.playerDetectionRange
	
	for _, player in ipairs(players) do
		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
			
			-- Only target alive players
			if humanoid and rootPart and humanoid.Health > 0 then
				local distance = (self.rootPart.Position - rootPart.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestPlayer = player
				end
			end
		end
	end
	
	return nearestPlayer
end

--[[
	Finds the nearest player-built structure within detection range
	@return BasePart or nil, distance number or nil
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
	
	return nearestStructure, nearestDistance
end

--[[
	Gets the position of a target (handles Players and BaseParts)
	@return Vector3 or nil
]]
function ZombieAI:GetTargetPosition(target)
	if not target then
		return nil
	end
	
	-- Handle Player targets
	if target:IsA("Player") then
		if target.Character then
			local rootPart = target.Character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				return rootPart.Position
			end
		end
		return nil
	end
	
	-- Handle BasePart targets
	if target:IsA("BasePart") and target.Parent then
		return target.Position
	end
	
	return nil
end

--[[
	Calculates a path to the target position using PathfindingService
]]
function ZombieAI:CalculatePath(targetPosition)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true, -- Allow jumping over obstacles
		AgentCanClimb = false,
		WaypointSpacing = 3, -- Tighter waypoint spacing for better following
		Costs = {
			Water = math.huge,
		}
	})
	
	local success, errorMessage = pcall(function()
		path:ComputeAsync(self.rootPart.Position, targetPosition)
	end)
	
	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		
		-- Convert waypoints to Vector3 positions (skip first waypoint if it's where we are)
		self.currentPath = {}
		for i, waypoint in ipairs(waypoints) do
			if i > 1 or (self.rootPart.Position - waypoint.Position).Magnitude > 2 then
				table.insert(self.currentPath, waypoint.Position)
			end
		end
		
		-- Reset waypoint index on new path
		self.currentWaypoint = 1
		
		-- If path is empty or very short, move directly
		if #self.currentPath == 0 then
			self.currentPath = nil
		end
	else
		-- Path failed, clear path and move directly
		self.currentPath = nil
		self.currentWaypoint = 1
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
