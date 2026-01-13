# Zombie Defense
A Wave-Based Base Building Roblox Game

## Description
Zombie Defense is a wave-based zombie defense game centered around base building, traps, and escalating difficulty. The design intentionally expects frequent base failure — players are meant to fail, learn, redesign, and try again.

## Game Design Philosophy
- **Failure is Learning**: Players are expected to fail and redesign their approach
- **Strategic Base Building**: Modular base construction with walls and floors
- **Trap-Based Defense**: Place traps on structures to defend against zombie waves
- **Active Combat**: Players fight zombies with weapons while earning currency
- **Progressive Difficulty**: Each wave increases in challenge

## Core Game Rules
- Players build a modular base using walls and floors
- Zombies spawn in waves and attempt to destroy the base
- **Target Priority**: Zombies attack player-built structures first, then the Base Core
- **Game Over**: The run ends when the Base Core is destroyed
- Traps must be placed on existing walls or floors
- Traps don't take damage; they stop working only if their structure is destroyed
- Players earn currency from zombie kills
- Player combat progression is separate from base progression

## Current Implementation Status

### ✅ Completed: ZombieAI Module (MVP)
The foundation of the game's enemy system is complete and ready for integration.

**Features:**
- **State Machine**: Clean implementation with 4 states (Idle, MoveToTarget, Attack, Dead)
- **Smart Pathfinding**: Uses Roblox PathfindingService to navigate toward targets
- **Priority Targeting**: Detects and prioritizes nearby player-built structures over Base Core
- **Configurable Stats**: Easily customize zombie behavior via config tables
- **Modular Architecture**: Clean, readable code that's easy to extend

**Technical Details:**
- Uses CollectionService tags ("Structure") to identify player-built structures
- Damage abstraction via callback function (no hardcoded structure logic)
- Configurable detection range (18 studs), attack range (6 studs)
- Configurable damage (10), attack cooldown (1.0s), move speed (16)
- Automatic cleanup and connection management

### 🔨 Next Steps (Not Yet Implemented)
The following systems are designed but awaiting implementation:
- Base Core system and placement
- Modular base building (walls/floors)
- Trap system and placement
- Wave spawning system
- Player weapons and combat
- Currency and shop system
- Structure health system

## Project Structure
```
Zombie Defense/
├── README.md
└── Robloxgame/
    ├── default.project.json     # Rojo project configuration
    └── src/
        └── Modules/
            └── ZombieAI.lua     # MVP zombie controller
```

## Getting Started

### Prerequisites
- [Roblox Studio](https://www.roblox.com/create)
- [Rojo](https://rojo.space/) (for syncing code)

### Installation
1. Clone this repository
2. Install Rojo if you haven't already
3. Open Roblox Studio
4. Run `rojo serve Robloxgame` in the project directory
5. Connect to Rojo from Roblox Studio using the Rojo plugin

## Development

### Using the ZombieAI Module

```lua
local CollectionService = game:GetService("CollectionService")
local ZombieAI = require(game.ServerScriptService.Modules.ZombieAI)

-- Create a Base Core (target for zombies)
local baseCore = Instance.new("Part")
baseCore.Size = Vector3.new(4, 4, 4)
baseCore.Position = Vector3.new(0, 2, 0)
baseCore.Anchored = true
baseCore.BrickColor = BrickColor.new("Bright red")
baseCore.Parent = workspace

-- Create a zombie model (must have Humanoid and HumanoidRootPart)
local zombieModel = -- your zombie model here

-- Optional: Create structures for zombies to attack
local structure = Instance.new("Part")
structure.Size = Vector3.new(10, 10, 1)
structure.Position = Vector3.new(15, 5, 0)
structure.Anchored = true
CollectionService:AddTag(structure, "Structure")
structure.Parent = workspace

-- Configuration
local config = {
	damage = 10,
	attackCooldown = 1.0,
	attackRange = 6,
	structureDetectionRange = 18,
	moveSpeed = 16,
	pathfindingUpdateInterval = 1.0,
	
	-- Damage callback
	damageTarget = function(target, amount)
		print(string.format("Zombie dealt %d damage to %s", amount, target.Name))
		-- Implement your structure health system here
	end
}

-- Initialize and start the zombie AI
local zombie = ZombieAI.new(zombieModel, baseCore, config)
zombie:Start()

-- Later, to stop:
-- zombie:Stop()
```

### Technical Architecture

**Language**: Luau (Roblox)

**Code Principles:**
- Modular design using ModuleScripts
- Clean, readable state machines
- Explicit use of Roblox services (PathfindingService, RunService, CollectionService)
- No over-engineering - only requested features implemented
- Easy to extend and modify

**ZombieAI State Machine:**
1. **Idle**: Find a target (structure or base core)
2. **MoveToTarget**: Pathfind toward target, switching if closer structure detected
3. **Attack**: Deal damage at intervals while in range
4. **Dead**: Cleanup state when zombie dies

### What's NOT Included (By Design)
Following the MVP philosophy, these are intentionally not implemented yet:
- No UI systems
- No monetization
- No cosmetics
- No meta-progression
- No player weapons/combat (structure only)
- No wave spawning
- No structure building system

These can be added incrementally as requested.

## Contributing
Contributions are welcome! This project follows a minimal, focused approach - only add explicitly requested features.

## License
This project is open source and available for educational purposes.
