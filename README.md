# Save-the-World
A Roblox Game Project

## Description
This is a Roblox game project designed to create an engaging gaming experience. The project uses Rojo for syncing code with Roblox Studio.

## Project Structure
```
Save-the-World/
├── README.md
└── Robloxgame/
    ├── default.project.json     # Rojo project configuration
    └── src/
        └── MakeBigScript.server.lua # Test script (Script type via .server.lua extension)
```

## Getting Started

### Prerequisites
- [Roblox Studio](https://www.roblox.com/create)
- [Rojo](https://rojo.space/) (for syncing code)

### Installation
1. Clone this repository
2. Install Rojo if you haven't already
3. Open Roblox Studio
4. Run `rojo serve` in the project directory
5. Connect to Rojo from Roblox Studio

## Development
The test script is located in `Robloxgame/src/MakeBigScript.server.lua`. The `.server.lua` extension tells Rojo to create it as a Script (not ModuleScript), so it runs automatically in ServerScriptService. The script will make your character 3x bigger when you spawn, which helps verify that Rojo syncing is working correctly.

### Testing Rojo Setup
1. Run `rojo serve` in the Robloxgame directory
2. Open Roblox Studio and create a new place or open an existing one
3. Install the Rojo plugin in Studio if you haven't already
4. Click the Rojo plugin and connect to localhost:34872
5. Click "Play" in Studio - your character should spawn 3x bigger!
6. Check the Output window for confirmation messages

## Contributing
Contributions are welcome! Feel free to submit issues or pull requests.

## License
This project is open source and available for educational purposes.
