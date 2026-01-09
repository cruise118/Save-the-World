--[[
    Save the World - Main Game Script
    This script handles the core game logic and initialization
]]

-- Print welcome message
print("Save the World - Game Starting...")

-- Game Configuration
local GameConfig = {
    GameName = "Save the World",
    Version = "1.0.0",
    MaxPlayers = 10,
    RoundDuration = 300 -- 5 minutes in seconds
}

-- Display game information
print("Game Name: " .. GameConfig.GameName)
print("Version: " .. GameConfig.Version)
print("Max Players: " .. GameConfig.MaxPlayers)

-- Initialize game state
local GameState = {
    IsActive = false,
    CurrentRound = 0,
    Players = {}
}

-- Function to start a new game round
local function StartRound()
    GameState.CurrentRound = GameState.CurrentRound + 1
    GameState.IsActive = true
    print("Round " .. GameState.CurrentRound .. " started!")
    print("Round duration: " .. GameConfig.RoundDuration .. " seconds")
end

-- Function to end the current round
local function EndRound()
    GameState.IsActive = false
    print("Round " .. GameState.CurrentRound .. " ended!")
end

-- Function to handle player joining
local function OnPlayerJoin(player)
    table.insert(GameState.Players, player.Name)
    print("Player joined: " .. player.Name)
    print("Total players: " .. #GameState.Players)
end

-- Function to handle player leaving
local function OnPlayerLeave(player)
    for i, name in ipairs(GameState.Players) do
        if name == player.Name then
            table.remove(GameState.Players, i)
            break
        end
    end
    print("Player left: " .. player.Name)
    print("Total players: " .. #GameState.Players)
end

-- Connect player events
game.Players.PlayerAdded:Connect(OnPlayerJoin)
game.Players.PlayerRemoving:Connect(OnPlayerLeave)

-- Start the first round
StartRound()

-- Game loop (placeholder for future expansion)
print("Game initialized successfully!")
print("Save the World is now running...")