--[[
	BuildClient.client.lua
	Client-side building system with ghost preview
	Handles input, ghost visualization, and communicates with server
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Wait for RemoteEvents
local buildRemotes = ReplicatedStorage:WaitForChild("BuildRemotes")
local PlaceStructureRemote = buildRemotes:WaitForChild("PlaceStructure")
local DeleteStructureRemote = buildRemotes:WaitForChild("DeleteStructure")

-- Wait for BuildEvents
local buildEvents = ReplicatedStorage:WaitForChild("BuildEvents")
local slotSelected = buildEvents:WaitForChild("SlotSelected")
local slotDeselected = buildEvents:WaitForChild("SlotDeselected")
local selectSlotRemote = buildEvents:WaitForChild("SelectSlot")
local deselectSlotRemote = buildEvents:WaitForChild("DeselectSlot")

-- Build mode state
local buildMode = {
	active = false,
	selectedSlot = nil,  -- 1 = floor, 2 = wall, 3 = trap
	rotation = 0,  -- Current rotation angle
	ghost = nil,  -- Current ghost preview part
	maxDistance = 50,  -- Max build distance
}

-- Constants
local TILE_SIZE = 16
local ROTATION_INCREMENT = 90

-- Slot configuration
local SLOT_CONFIG = {
	[1] = { type = "floor", size = Vector3.new(16, 1, 16), color = Color3.fromRGB(120, 120, 120), name = "Floor" },
	[2] = { type = "wall", size = Vector3.new(16, 8, 1), color = Color3.fromRGB(150, 150, 150), name = "Wall" },
	[3] = { type = "trap", size = Vector3.new(15.8, 0.5, 15.8), color = Color3.fromRGB(180, 50, 50), name = "Spike Trap" },
}

-- Snap position to grid
local function SnapToGrid(position)
	local x = math.floor((position.X / TILE_SIZE) + 0.5) * TILE_SIZE
	local z = math.floor((position.Z / TILE_SIZE) + 0.5) * TILE_SIZE
	return Vector3.new(x, 0.5, z)
end

-- Create or update ghost preview
local function UpdateGhost()
	-- Remove old ghost
	if buildMode.ghost then
		buildMode.ghost:Destroy()
		buildMode.ghost = nil
	end
	
	if not buildMode.active or not buildMode.selectedSlot then
		return
	end
	
	local config = SLOT_CONFIG[buildMode.selectedSlot]
	if not config then
		return
	end
	
	-- Create ghost part
	local ghost = Instance.new("Part")
	ghost.Name = "BuildGhost"
	ghost.Size = config.size
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.Transparency = 0.5
	ghost.Material = Enum.Material.SmoothPlastic
	ghost.Color = config.color
	ghost.Parent = workspace
	
	buildMode.ghost = ghost
end

-- Update ghost position based on mouse
local function UpdateGhostPosition()
	if not buildMode.ghost or not buildMode.active then
		return
	end
	
	local character = player.Character
	if not character then
		return
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	
	-- Raycast from mouse
	local ray = mouse.UnitRay
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character, buildMode.ghost}
	
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
	
	if result then
		local hitPos = result.Position
		local snappedPos = SnapToGrid(hitPos)
		
		-- Adjust Y position based on type
		local config = SLOT_CONFIG[buildMode.selectedSlot]
		if config.type == "floor" then
			buildMode.ghost.Position = snappedPos
		elseif config.type == "wall" then
			buildMode.ghost.Position = Vector3.new(snappedPos.X, config.size.Y / 2 + 0.5, snappedPos.Z)
		elseif config.type == "trap" then
			-- Snap to floor position
			buildMode.ghost.Position = Vector3.new(snappedPos.X, 0.75, snappedPos.Z)
		end
		
		-- Apply rotation
		buildMode.ghost.Orientation = Vector3.new(0, buildMode.rotation, 0)
		
		-- Check if within build distance
		local distance = (rootPart.Position - buildMode.ghost.Position).Magnitude
		if distance > buildMode.maxDistance then
			buildMode.ghost.Color = Color3.fromRGB(255, 100, 100)  -- Red for out of range
		else
			buildMode.ghost.Color = config.color  -- Normal color
		end
	else
		-- No hit, hide ghost
		buildMode.ghost.Position = Vector3.new(0, -1000, 0)
	end
end

-- Select a build slot (1-3)
local function SelectSlot(slotNumber)
	if slotNumber < 1 or slotNumber > 3 then
		return
	end
	
	buildMode.selectedSlot = slotNumber
	buildMode.active = true
	UpdateGhost()
	
	-- Update UI
	slotSelected:Fire(slotNumber)
end

-- Deselect current slot
local function DeselectSlot()
	buildMode.active = false
	buildMode.selectedSlot = nil
	
	if buildMode.ghost then
		buildMode.ghost:Destroy()
		buildMode.ghost = nil
	end
	
	-- Update UI
	slotDeselected:Fire()
end

-- Rotate ghost
local function RotateGhost()
	buildMode.rotation = (buildMode.rotation + ROTATION_INCREMENT) % 360
	if buildMode.ghost then
		buildMode.ghost.Orientation = Vector3.new(0, buildMode.rotation, 0)
	end
end

-- Place structure
local function PlaceStructure()
	if not buildMode.active or not buildMode.ghost then
		return
	end
	
	local character = player.Character
	if not character then
		return
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	
	-- Check distance
	local distance = (rootPart.Position - buildMode.ghost.Position).Magnitude
	if distance > buildMode.maxDistance then
		warn("Too far to build!")
		return
	end
	
	local config = SLOT_CONFIG[buildMode.selectedSlot]
	local position = buildMode.ghost.Position
	local rotation = buildMode.rotation
	
	-- Send to server
	PlaceStructureRemote:FireServer(config.type, position, rotation)
end

-- Delete structure under mouse
local function DeleteStructureUnderMouse()
	local character = player.Character
	if not character then
		return
	end
	
	-- Raycast from mouse
	local ray = mouse.UnitRay
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character}
	
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
	
	if result and result.Instance then
		local part = result.Instance
		-- Check if it's a structure or trap
		if part.Parent and (part.Parent.Name == "Structures" or part.Parent.Name == "Traps") then
			DeleteStructureRemote:FireServer(part)
		end
	end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	
	-- Number keys 1-3 for slot selection
	if input.KeyCode == Enum.KeyCode.One then
		SelectSlot(1)
	elseif input.KeyCode == Enum.KeyCode.Two then
		SelectSlot(2)
	elseif input.KeyCode == Enum.KeyCode.Three then
		SelectSlot(3)
	elseif input.KeyCode == Enum.KeyCode.R then
		-- R to rotate
		RotateGhost()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		-- Escape to cancel
		DeselectSlot()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- Left click to place
		if buildMode.active then
			PlaceStructure()
		end
	end
end)

-- Update ghost position every frame
RunService.RenderStepped:Connect(function()
	if buildMode.active and buildMode.ghost then
		UpdateGhostPosition()
	end
end)

-- Listen for UI events
selectSlotRemote.Event:Connect(SelectSlot)
deselectSlotRemote.Event:Connect(DeselectSlot)

print("[BuildClient] Build system initialized")
