# Save-the-World
A Roblox Game Project

## Description
This is an interactive Roblox game featuring player size controls and a portal teleportation system. Built with Rojo for seamless code synchronization with Roblox Studio.

## Features

### Size Control System
- Interactive UI with +/- buttons to adjust player size
- Size range: 0.5x to 5.0x normal size
- Size persists through character respawns
- Supports both R15 and R6 character types
- Server-side validation and anti-exploit measures

### Portal System
- Create custom teleportation portals
- Set entry and exit points anywhere in the world
- Visual portal indicators (blue for entry, orange for exit)
- Portal management UI:
  - Create new portal pairs
  - List all active portals
  - Remove portals (creators only)
- Teleportation cooldown to prevent rapid re-teleports
- Automatic cleanup of invalid portals

## Project Structure
```
Save-the-World/
├── README.md
└── Robloxgame/
    ├── default.project.json     # Rojo project configuration
    └── src/
        ├── ServerScripts/       # Server-side logic
        │   ├── SizeControlServer.server.lua
        │   └── PortalServer.server.lua
        ├── ClientScripts/       # Client-side UI scripts
        │   ├── SizeControlUI.client.lua
        │   └── PortalUI.client.lua
        └── UI/                  # UI structure definitions
            ├── SizeControlGui.lua
            └── PortalGui.lua
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
This project uses Rojo to sync code between your filesystem and Roblox Studio.

### How to Use the Game

#### Size Control
1. Look for the Size Control panel on the left side of the screen
2. Click "+ Increase" to make your character bigger (up to 5x)
3. Click "- Decrease" to make your character smaller (down to 0.5x)
4. Your size persists even after respawning

#### Portal System
1. Find the Portal System panel on the right side of the screen
2. To create a portal:
   - Click "Create Portal"
   - Click anywhere in the world to set the ENTRY point
   - Click another location to set the EXIT point
   - Portal pair is created instantly
3. To remove a portal:
   - Click "List Portals" to see all active portals
   - Click on a portal in the list to select it
   - Click "Remove Portal" to delete it
4. Walk through any portal to teleport to its paired destination

### Technical Details

#### Size Control System
- Uses RemoteEvents for secure client-server communication
- Server validates all size changes to prevent exploits
- Stores player size data for persistence
- Handles both R15 (using BodyScale values) and R6 (scaling parts) characters
- Includes size limits (0.5x - 5.0x) and rate limiting

#### Portal System
- Portal pairs consist of entry (blue) and exit (orange) portals
- Touch-based teleportation with cooldown system
- Prevents rapid re-teleportation with cooldown tracking
- Server-side portal management for security
- Automatic cleanup of broken/invalid portals
- Permission system (only creators can remove their portals)
- Bi-directional teleportation (works both ways)

### Testing Rojo Setup
1. Run `rojo serve` in the Robloxgame directory
2. Open Roblox Studio and create a new place or open an existing one
3. Install the Rojo plugin in Studio if you haven't already
4. Click the Rojo plugin and connect to localhost:34872
5. Click "Play" in Studio
6. You should see two UI panels appear:
   - Size Control on the left
   - Portal System on the right
7. Test the features to verify everything is working

### Error Handling & Edge Cases

The system handles various scenarios:
- **Size Control**: Size limits, character not found, invalid requests
- **Portal System**: 
  - Missing portal destinations (cleanup)
  - Rapid re-teleportation (cooldown)
  - Invalid portal positions
  - Permission checks for portal removal
  - Automatic cleanup of orphaned portals
  - Player in portal tracking to prevent loops

## Contributing
Contributions are welcome! Feel free to submit issues or pull requests.

## License
This project is open source and available for educational purposes.
