--[[
	HealthBarClient.client.lua
	Renders health bars above structures ONLY when hovering over them
	Also adds dark outlines to all structures
	
	Updates in real-time when structures take damage
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Health bar configuration
local HEALTH_BAR_CONFIG = {
	size = UDim2.new(4, 0, 0.5, 0),
	studOffset = Vector3.new(0, 5, 0),
	updateInterval = 0.1, -- Update health bars every 0.1 seconds
}

-- Store health bars and outlines for cleanup
local healthBars = {} -- { [structure] = billboardGui }
local outlines = {} -- { [structure] = selectionBox }
local currentHoveredStructure = nil

-- Color gradient based on health percentage
local function GetHealthColor(healthPercent)
	if healthPercent > 0.6 then
		-- Green to Yellow
		local t = (healthPercent - 0.6) / 0.4
		return Color3.new(1 - t * 0.5, 1, 0)
	elseif healthPercent > 0.3 then
		-- Yellow to Orange
		local t = (healthPercent - 0.3) / 0.3
		return Color3.new(1, 1 * t, 0)
	else
		-- Orange to Red
		local t = healthPercent / 0.3
		return Color3.new(1, 0.5 * t, 0)
	end
end

-- Create health bar for a structure (hidden by default)
local function CreateHealthBar(structure)
	if not structure:IsA("BasePart") then
		return
	end
	
	-- Don't create multiple health bars
	if healthBars[structure] then
		return
	end
	
	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = HEALTH_BAR_CONFIG.size
	billboard.StudsOffset = HEALTH_BAR_CONFIG.studOffset
	billboard.AlwaysOnTop = true
	billboard.Adornee = structure
	billboard.Enabled = false  -- Hidden by default
	
	-- Background frame
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	background.BorderSizePixel = 1
	background.BorderColor3 = Color3.fromRGB(0, 0, 0)
	background.Parent = billboard
	
	-- Health bar frame
	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = background
	
	-- Health text
	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = "100%"
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.TextScaled = true
	healthText.Font = Enum.Font.GothamBold
	healthText.TextStrokeTransparency = 0.5
	healthText.Parent = background
	
	billboard.Parent = structure
	
	-- Store reference
	healthBars[structure] = billboard
	
	-- Update immediately
	local maxHealth = structure:GetAttribute("MaxHealth") or 100
	local currentHealth = structure:GetAttribute("Health") or maxHealth
	local healthPercent = math.clamp(currentHealth / maxHealth, 0, 1)
	
	healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
	healthBar.BackgroundColor3 = GetHealthColor(healthPercent)
	healthText.Text = string.format("%d%%", math.floor(healthPercent * 100))
end

-- Create dark outline for a structure
local function CreateOutline(structure)
	if not structure:IsA("BasePart") then
		return
	end
	
	-- Don't create multiple outlines
	if outlines[structure] then
		return
	end
	
	-- Create SelectionBox
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Name = "StructureOutline"
	selectionBox.Adornee = structure
	selectionBox.LineThickness = 0.03
	selectionBox.Color3 = Color3.fromRGB(30, 30, 30)  -- Dark outline
	selectionBox.SurfaceColor3 = Color3.fromRGB(30, 30, 30)
	selectionBox.SurfaceTransparency = 1  -- No surface fill, just outline
	selectionBox.Parent = structure
	
	-- Store reference
	outlines[structure] = selectionBox
end

-- Update health bar display
local function UpdateHealthBar(structure)
	local billboard = healthBars[structure]
	if not billboard or not billboard.Parent then
		healthBars[structure] = nil
		return
	end
	
	local maxHealth = structure:GetAttribute("MaxHealth") or 100
	local currentHealth = structure:GetAttribute("Health") or maxHealth
	local healthPercent = math.clamp(currentHealth / maxHealth, 0, 1)
	
	local healthBar = billboard:FindFirstChild("Background"):FindFirstChild("HealthBar")
	local healthText = billboard:FindFirstChild("Background"):FindFirstChild("HealthText")
	
	if healthBar and healthText then
		healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
		healthBar.BackgroundColor3 = GetHealthColor(healthPercent)
		healthText.Text = string.format("%d%%", math.floor(healthPercent * 100))
	end
	
	-- Remove health bar if structure is destroyed
	if currentHealth <= 0 then
		billboard:Destroy()
		healthBars[structure] = nil
	end
end

-- Remove health bar when structure is removed
local function RemoveHealthBar(structure)
	local billboard = healthBars[structure]
	if billboard then
		billboard:Destroy()
		healthBars[structure] = nil
	end
end

-- Remove outline when structure is removed
local function RemoveOutline(structure)
	local selectionBox = outlines[structure]
	if selectionBox then
		selectionBox:Destroy()
		outlines[structure] = nil
	end
end

-- Initialize health bars and outlines for existing structures
local function InitializeExistingStructures()
	for _, structure in ipairs(CollectionService:GetTagged("Structure")) do
		CreateHealthBar(structure)
		CreateOutline(structure)
	end
end

-- Listen for new structures
CollectionService:GetInstanceAddedSignal("Structure"):Connect(function(structure)
	task.wait(0.1) -- Small delay to ensure attributes are set
	CreateHealthBar(structure)
	CreateOutline(structure)
end)

-- Listen for removed structures
CollectionService:GetInstanceRemovedSignal("Structure"):Connect(function(structure)
	RemoveHealthBar(structure)
	RemoveOutline(structure)
end)

-- Update health bars periodically
local lastUpdateTime = 0
RunService.RenderStepped:Connect(function()
	local now = tick()
	if now - lastUpdateTime < HEALTH_BAR_CONFIG.updateInterval then
		return
	end
	lastUpdateTime = now
	
	-- Check what the mouse is hovering over
	local target = mouse.Target
	local hoveredStructure = nil
	
	-- Check if target is a structure or part of a structure
	if target and CollectionService:HasTag(target, "Structure") then
		hoveredStructure = target
	end
	
	-- Update health bar visibility
	if hoveredStructure ~= currentHoveredStructure then
		-- Hide previous health bar
		if currentHoveredStructure and healthBars[currentHoveredStructure] then
			healthBars[currentHoveredStructure].Enabled = false
		end
		
		-- Show new health bar
		if hoveredStructure and healthBars[hoveredStructure] then
			healthBars[hoveredStructure].Enabled = true
		end
		
		currentHoveredStructure = hoveredStructure
	end
	
	-- Update currently visible health bar
	if currentHoveredStructure and healthBars[currentHoveredStructure] then
		UpdateHealthBar(currentHoveredStructure)
	end
	
	-- Clean up health bars for destroyed structures
	for structure, _ in pairs(healthBars) do
		if not structure or not structure.Parent then
			healthBars[structure] = nil
		end
	end
	
	-- Clean up outlines for destroyed structures
	for structure, _ in pairs(outlines) do
		if not structure or not structure.Parent then
			outlines[structure] = nil
		end
	end
end)

-- Initialize
InitializeExistingStructures()

print("[HealthBarClient] Initialized - health bars show on hover, all structures have dark outlines")
