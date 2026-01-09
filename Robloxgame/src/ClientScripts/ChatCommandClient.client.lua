-- ChatCommandClient.client.lua
-- Client-side chat command handler for Zombie Defense MVP
-- Listens for local player messages and forwards commands to server

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for ChatCommand RemoteEvent (server creates it)
local chatCommandRemote = ReplicatedStorage:WaitForChild("ChatCommand", 10)

if not chatCommandRemote then
	warn("[ChatCommandClient] ChatCommand RemoteEvent not found in ReplicatedStorage")
	return
end

-- Listen for messages sent by the local player
TextChatService.MessageReceived:Connect(function(textChatMessage)
	-- Only process messages from the local player
	if not textChatMessage.TextSource then
		return
	end
	
	local message = textChatMessage.Text
	
	-- Only send commands (messages starting with !)
	if message:match("^!") then
		-- Fire to server
		chatCommandRemote:FireServer(message)
	end
end)

print("[ChatCommandClient] Chat command bridge initialized")
