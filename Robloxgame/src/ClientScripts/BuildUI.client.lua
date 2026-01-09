--[[
	BuildUI.client.lua
	Creates and manages the building hotbar UI at the bottom of the screen
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for build client
local BuildClient = require(script.Parent:WaitForChild("BuildClient"))

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BuildUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Hotbar frame (bottom center)
local hotbarFrame = Instance.new("Frame")
hotbarFrame.Name = "HotbarFrame"
hotbarFrame.Size = UDim2.new(0, 400, 0, 80)
hotbarFrame.Position = UDim2.new(0.5, -200, 1, -100)
hotbarFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
hotbarFrame.BackgroundTransparency = 0.3
hotbarFrame.BorderSizePixel = 0
hotbarFrame.Parent = screenGui

-- Add corner rounding
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hotbarFrame

-- Slot configuration
local SLOTS = {
	{name = "Floor", key = "1", color = Color3.fromRGB(120, 200, 120)},
	{name = "Wall", key = "2", color = Color3.fromRGB(200, 200, 120)},
	{name = "Trap", key = "3", color = Color3.fromRGB(200, 120, 120)},
}

local slotButtons = {}
local selectedSlot = nil

-- Create slot button
local function CreateSlotButton(slotIndex, slotData)
	local button = Instance.new("TextButton")
	button.Name = "Slot" .. slotIndex
	button.Size = UDim2.new(0, 70, 0, 70)
	button.Position = UDim2.new(0, 10 + (slotIndex - 1) * 80, 0.5, -35)
	button.BackgroundColor3 = slotData.color
	button.BackgroundTransparency = 0.2
	button.BorderSizePixel = 2
	button.BorderColor3 = Color3.fromRGB(80, 80, 80)
	button.Text = ""
	button.Parent = hotbarFrame
	
	-- Corner rounding
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = button
	
	-- Label for slot name
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0.5, 0)
	label.Position = UDim2.new(0, 0, 0.25, 0)
	label.BackgroundTransparency = 1
	label.Text = slotData.name
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = button
	
	-- Key indicator
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.Size = UDim2.new(0.3, 0, 0.3, 0)
	keyLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
	keyLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	keyLabel.BackgroundTransparency = 0.3
	keyLabel.Text = slotData.key
	keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	keyLabel.TextScaled = true
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.Parent = button
	
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 4)
	keyCorner.Parent = keyLabel
	
	-- Click handler
	button.MouseButton1Click:Connect(function()
		if selectedSlot == slotIndex then
			-- Deselect
			BuildClient.DeselectSlot()
		else
			-- Select this slot
			BuildClient.SelectSlot(slotIndex)
		end
	end)
	
	return button
end

-- Create all slot buttons
for i, slotData in ipairs(SLOTS) do
	slotButtons[i] = CreateSlotButton(i, slotData)
end

-- Delete button (right side)
local deleteButton = Instance.new("TextButton")
deleteButton.Name = "DeleteButton"
deleteButton.Size = UDim2.new(0, 70, 0, 70)
deleteButton.Position = UDim2.new(0, 320, 0.5, -35)
deleteButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
deleteButton.BackgroundTransparency = 0.2
deleteButton.BorderSizePixel = 2
deleteButton.BorderColor3 = Color3.fromRGB(80, 80, 80)
deleteButton.Text = "🗑️"
deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deleteButton.TextScaled = true
deleteButton.Font = Enum.Font.GothamBold
deleteButton.Parent = hotbarFrame

local deleteCorner = Instance.new("UICorner")
deleteCorner.CornerRadius = UDim.new(0, 8)
deleteCorner.Parent = deleteButton

-- Delete button functionality
local deleteMode = false
deleteButton.MouseButton1Click:Connect(function()
	deleteMode = not deleteMode
	BuildClient.DeselectSlot()
	
	if deleteMode then
		deleteButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
		-- Show delete cursor or indicator
	else
		deleteButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	end
end)

-- Handle delete mode clicks
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	
	if deleteMode and input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- Delete structure under mouse
		local mouse = player:GetMouse()
		local target = mouse.Target
		
		if target and target.Parent and (target.Parent.Name == "Structures" or target.Parent.Name == "Traps") then
			local buildRemotes = ReplicatedStorage:WaitForChild("BuildRemotes")
			local DeleteStructure = buildRemotes:WaitForChild("DeleteStructure")
			DeleteStructure:FireServer(target)
		end
	end
end)

-- Update selection visuals
local function UpdateSelectionVisuals(slotNumber)
	for i, button in ipairs(slotButtons) do
		if i == slotNumber then
			button.BorderColor3 = Color3.fromRGB(255, 255, 100)
			button.BorderSizePixel = 4
			selectedSlot = slotNumber
		else
			button.BorderColor3 = Color3.fromRGB(80, 80, 80)
			button.BorderSizePixel = 2
		end
	end
	
	-- Reset delete button
	if slotNumber then
		deleteMode = false
		deleteButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	end
end

local function ClearSelection()
	for _, button in ipairs(slotButtons) do
		button.BorderColor3 = Color3.fromRGB(80, 80, 80)
		button.BorderSizePixel = 2
	end
	selectedSlot = nil
end

-- Listen for selection events
local buildEvents = ReplicatedStorage:FindFirstChild("BuildEvents")
if not buildEvents then
	buildEvents = Instance.new("Folder")
	buildEvents.Name = "BuildEvents"
	buildEvents.Parent = ReplicatedStorage
end

local slotSelected = buildEvents:FindFirstChild("SlotSelected")
if not slotSelected then
	slotSelected = Instance.new("BindableEvent")
	slotSelected.Name = "SlotSelected"
	slotSelected.Parent = buildEvents
end

local slotDeselected = buildEvents:FindFirstChild("SlotDeselected")
if not slotDeselected then
	slotDeselected = Instance.new("BindableEvent")
	slotDeselected.Name = "SlotDeselected"
	slotDeselected.Parent = buildEvents
end

slotSelected.Event:Connect(UpdateSelectionVisuals)
slotDeselected.Event:Connect(ClearSelection)

print("[BuildUI] Hotbar initialized")
