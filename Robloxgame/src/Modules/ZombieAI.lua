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
	playerAcquireRange = 25, -- Range to start chasing player
	playerLoseRange = 32, -- Range to stop chasing player (hysteresis)
	playerCommitTime = 1.0, -- Seconds to keep chasing player before reconsidering
	
	-- Movement
	moveSpeed = 14, -- Slower than default player speed (16)
	pathfindingUpdateInterval = 1.0, -- Reduced for smoother movement
	waypointReachedDistance = 3, -- Distance to consider waypoint reached
	minWaypointAdvanceDistance = 3, -- Minimum distance to advance waypoint on path recalc
	moveToUpdateThreshold = 1, -- Only update MoveTo if waypoint differs by this much
	
	-- Stuck detection
	stuckDetectionTime = 1.0, -- Time to wait before checking if stuck
	stuckDistanceThreshold = 1, -- If moved less than this in stuckDetectionTime, recalc path
	targetMovedThreshold = 6, -- Recalc if target moved this far
	
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
	self.currentTargetType = "BaseCore" -- "BaseCore" | "Structure" | "Player"
	
	-- Timers
	self.lastAttackTime = 0
	self.lastPathUpdateTime = 0
	self.lastTargetSwitchTime = 0 -- Track when we last switched targets
	
	-- Pathfinding
	self.currentPath = nil
	self.currentWaypoint = 1
	self._lastMoveToPosition = nil -- Track last MoveTo position to avoid spam
	self.lastTargetPosition = nil -- Track target position for movement detection
	
	-- Stuck detection
	self.lastStuckCheckTime = 0
	self.lastStuckCheckPosition = nil
	
	-- Connection tracking
	self.connections = {}
	self.isActive = false
	self._loopRunning = false
	self._moveToFinishedConnection = nil -- Track MoveToFinished connection
	
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
	self.humanoid.AutoRotate = true -- Let Roblox handle rotation naturally
	
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
	-- Priority: Player > Structure > Base Core
	
	-- First check for nearby players
	local nearestPlayer = self:FindNearestPlayer()
	if nearestPlayer then
		self.currentTarget = nearestPlayer
		self.currentTargetType = "Player"
		self.lastTargetSwitchTime = time()
		self:SetState(State.MoveToTarget)
		return
	end
	
	-- Then check for structures
	local target, _ = self:FindNearestStructure()
	if target then
		self.currentTarget = target
		self.currentTargetType = "Structure"
		self.lastTargetSwitchTime = time()
		self:SetState(State.MoveToTarget)
		return
	end
	
	-- Fall back to base core
	self.currentTarget = self.baseCore
	self.currentTargetType = "BaseCore"
	self.lastTargetSwitchTime = time()
	self:SetState(State.MoveToTarget)
end

--[[
	Move state: Pathfind toward current target
]]
function ZombieAI:UpdateMove()
	local currentTime = time()
	
	-- Handle player targeting with hysteresis and commit time
	if self.currentTargetType == "Player" then
		-- Currently chasing a player
		local timeSinceSwitch = currentTime - self.lastTargetSwitchTime
		local shouldDropPlayer = false
		
		-- Check if player is still valid
		if not self.currentTarget or not self.currentTarget:IsA("Player") then
			shouldDropPlayer = true
		elseif self.currentTarget.Character then
			local humanoid = self.currentTarget.Character:FindFirstChildOfClass("Humanoid")
			local rootPart = self.currentTarget.Character:FindFirstChild("HumanoidRootPart")
			
			if not humanoid or not rootPart or humanoid.Health <= 0 then
				shouldDropPlayer = true
			else
				-- Check distance with playerLoseRange (hysteresis)
				local distance = (self.rootPart.Position - rootPart.Position).Magnitude
				if distance > self.config.playerLoseRange then
					shouldDropPlayer = true
				end
			end
		else
			shouldDropPlayer = true
		end
		
		-- Keep chasing for at least playerCommitTime before dropping
		if shouldDropPlayer and timeSinceSwitch >= self.config.playerCommitTime then
			-- Drop player target, find structure or base core
			self.currentTarget = nil
			self.currentTargetType = "BaseCore"
			local nearestStructure, _ = self:FindNearestStructure()
			if nearestStructure then
				self.currentTarget = nearestStructure
				self.currentTargetType = "Structure"
			else
				self.currentTarget = self.baseCore
			end
			self.lastTargetSwitchTime = currentTime
			self.currentPath = nil
			self.lastTargetPosition = nil
		end
	else
		-- Currently targeting structure or base core
		-- Check if a player came into acquisition range
		if (currentTime - self.lastTargetSwitchTime) > 0.5 then
			local nearestPlayer = self:FindNearestPlayer()
			if nearestPlayer then
				-- Switch to player
				self.currentTarget = nearestPlayer
				self.currentTargetType = "Player"
				self.lastTargetSwitchTime = currentTime
				self.currentPath = nil
				self.lastTargetPosition = nil
			end
		end
		
		-- Also check if we should switch structures
		if self.currentTargetType == "Structure" then
			-- Validate current target still exists
			if not self.currentTarget or not self.currentTarget.Parent then
				self.currentTarget = nil
			end
			
			-- If no current target, find structure or base core
			if not self.currentTarget then
				local nearestStructure, _ = self:FindNearestStructure()
				if nearestStructure then
					self.currentTarget = nearestStructure
					self.currentTargetType = "Structure"
				else
					self.currentTarget = self.baseCore
					self.currentTargetType = "BaseCore"
				end
				self.currentPath = nil
				self.lastTargetPosition = nil
			else
				-- We have a valid structure target, check if we should switch to a closer one
				local nearestStructure, nearestDistance = self:FindNearestStructure()
				if nearestStructure and nearestStructure ~= self.currentTarget then
					-- Only switch if meaningfully closer (20% threshold to prevent jitter)
					local targetPos = self:GetTargetPosition(self.currentTarget)
					if targetPos then
						local currentTargetDistance = (self.rootPart.Position - targetPos).Magnitude
						if nearestDistance < currentTargetDistance * 0.8 then
							self.currentTarget = nearestStructure
							self.currentTargetType = "Structure"
							self.currentPath = nil
							self.lastTargetPosition = nil
						end
					end
				end
			end
		end
	end
	
	-- Get current target position
	local targetPosition = self:GetTargetPosition(self.currentTarget)
	if not targetPosition then
		-- Target is invalid, go back to idle to find new target
		self:SetState(State.Idle)
		return
	end
	
	-- Check if in attack range
	local distanceToTarget = (self.rootPart.Position - targetPosition).Magnitude
	if distanceToTarget <= self.config.attackRange then
		self:SetState(State.Attack)
		return
	end
	
	-- Determine if we need to recalculate path
	local needsRecalc = false
	
	if not self.currentPath then
		needsRecalc = true
	elseif self.lastTargetPosition then
		-- Check if target moved significantly
		local targetMoved = (targetPosition - self.lastTargetPosition).Magnitude
		if targetMoved > self.config.targetMovedThreshold then
			needsRecalc = true
		end
	end
	
	-- Stuck detection: check if zombie hasn't moved much
	if not needsRecalc and (currentTime - self.lastStuckCheckTime) >= self.config.stuckDetectionTime then
		if self.lastStuckCheckPosition then
			local distanceMoved = (self.rootPart.Position - self.lastStuckCheckPosition).Magnitude
			if distanceMoved < self.config.stuckDistanceThreshold then
				needsRecalc = true
			end
		end
		self.lastStuckCheckTime = currentTime
		self.lastStuckCheckPosition = self.rootPart.Position
	end
	
	-- Recalculate path if needed
	if needsRecalc then
		self:CalculatePath(targetPosition)
		self.lastPathUpdateTime = currentTime
		self.lastTargetPosition = targetPosition
		-- Immediately issue MoveTo after path recalculation
		self:IssueMoveToCurrentWaypoint()
	end
	
	-- Follow path using event-driven waypoint progression (handled by MoveToFinished)
	-- This Update function only handles path recalculation logic
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
	
	-- If attacking a player, check if they're still in lose range
	if self.currentTargetType == "Player" then
		local distanceToTarget = (self.rootPart.Position - targetPosition).Magnitude
		if distanceToTarget > self.config.playerLoseRange then
			-- Player escaped, return to idle
			self:SetState(State.Idle)
			return
		end
	end
	
	-- Check if still in attack range
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
	
	-- Note: No manual CFrame rotation - let Humanoid.AutoRotate handle facing
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
	Finds the nearest player within acquisition range
	@return Player or nil
]]
function ZombieAI:FindNearestPlayer()
	local players = Players:GetPlayers()
	local nearestPlayer = nil
	local nearestDistance = self.config.playerAcquireRange
	
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
	Preserves waypoint progress to prevent "turning backwards" on recalc
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
		
		-- Convert waypoints to Vector3 positions
		local newPath = {}
		for _, waypoint in ipairs(waypoints) do
			table.insert(newPath, waypoint.Position)
		end
		
		-- Preserve waypoint progress: find best starting waypoint
		if #newPath > 0 then
			local currentPos = self.rootPart.Position
			local bestIndex = 1
			local bestDistance = math.huge
			
			-- Find closest waypoint to current position
			for i, wp in ipairs(newPath) do
				local dist = (currentPos - wp).Magnitude
				if dist < bestDistance then
					bestDistance = dist
					bestIndex = i
				end
			end
			
			-- Advance to first waypoint that's at least minWaypointAdvanceDistance ahead
			local startIndex = bestIndex
			for i = bestIndex, #newPath do
				local dist = (currentPos - newPath[i]).Magnitude
				if dist >= self.config.minWaypointAdvanceDistance then
					startIndex = i
					break
				end
			end
			
			-- If all waypoints are too close, either use last waypoint or clear path
			if startIndex == bestIndex and (currentPos - newPath[bestIndex]).Magnitude < self.config.minWaypointAdvanceDistance then
				-- Check if we can use a later waypoint
				if startIndex < #newPath then
					startIndex = #newPath
				else
					-- Path is too short/close, just move directly
					self.currentPath = nil
					return
				end
			end
			
			self.currentPath = newPath
			self.currentWaypoint = startIndex
			self._lastMoveToPosition = nil -- Clear to force immediate MoveTo
		else
			self.currentPath = nil
			self._lastMoveToPosition = nil
		end
	else
		-- Path failed, clear path and move directly
		self.currentPath = nil
		self.currentWaypoint = 1
		self._lastMoveToPosition = nil
	end
end

--[[
	Issues a MoveTo command to the current waypoint
	Helper function to avoid code duplication
]]
function ZombieAI:IssueMoveToCurrentWaypoint()
	if not self.currentPath or self.currentWaypoint > #self.currentPath then
		return
	end
	
	local waypoint = self.currentPath[self.currentWaypoint]
	self.humanoid:MoveTo(waypoint)
	self._lastMoveToPosition = waypoint
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
		-- Disconnect MoveToFinished connection
		if self._moveToFinishedConnection then
			self._moveToFinishedConnection:Disconnect()
			self._moveToFinishedConnection = nil
		end
	end
	
	self.state = newState
	
	-- State enter logic
	if newState == State.MoveToTarget then
		-- Connect to MoveToFinished for event-driven waypoint progression
		self._moveToFinishedConnection = self.humanoid.MoveToFinished:Connect(function(reached)
			if self.state == State.MoveToTarget then
				if reached then
					-- Successfully reached waypoint, advance to next
					self.currentWaypoint = self.currentWaypoint + 1
					-- Immediately issue MoveTo to next waypoint
					self:IssueMoveToCurrentWaypoint()
				else
					-- Failed to reach waypoint (pathfinding issue or stuck)
					-- Mark as stuck and force recalculation
					self.currentPath = nil
					self._lastMoveToPosition = nil
					
					-- Get current target position and recalculate immediately
					local targetPosition = self:GetTargetPosition(self.currentTarget)
					if targetPosition then
						self:CalculatePath(targetPosition)
						self.lastTargetPosition = targetPosition
						self:IssueMoveToCurrentWaypoint()
					end
				end
			end
		end)
	elseif newState == State.Dead then
		-- Stop movement on death
		if self.humanoid.Parent and self.rootPart.Parent then
			self.humanoid:MoveTo(self.rootPart.Position)
		end
	elseif newState == State.Attack then
		-- Stop movement when entering attack
		if self.humanoid.Parent and self.rootPart.Parent then
			self.humanoid:MoveTo(self.rootPart.Position)
		end
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
