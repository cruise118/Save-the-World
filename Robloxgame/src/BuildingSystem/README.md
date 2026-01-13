# Building System Documentation

## Overview

This is a Fortnite-style building system for Roblox that provides a modular, deterministic grid-based building mechanic with support validation and cascade destruction.

## Architecture

The system is composed of four main services and one configuration module:

### 1. BuildConfig
Configuration constants including:
- Grid settings (TileSize: 4 studs, LevelHeight: 3 studs)
- Structure types (Floor, Wall, Ramp)
- Material tiers (Wood, Stone, Metal) with HP values
- Rotation constraints (0°, 90°, 180°, 270°)
- Validation error messages

### 2. BuildGridService
Manages the discrete tile grid system:
- **Grid Coordinate System**: Discrete integer-based grid (X/Z)
- **Level System**: Integer vertical levels (Y-axis)
- **Tile Occupancy Tracking**: Prevents overlaps
- **Coordinate Conversion**: World ↔ Grid position transformation
- **Terrain Support**: Hardcoded ground-level support (MVP)

**Key Methods:**
- `SnapToGrid(x, z)`: Snap world coordinates to grid
- `WorldToGrid(worldX, worldZ)`: Convert world position to grid coordinates
- `GridToWorld(gridX, gridZ, level)`: Convert grid coordinates to world position
- `IsTileOccupied(gridX, gridZ, level, structureType)`: Check if tile is occupied
- `OccupyTile(...)`: Mark tile as occupied
- `RemoveStructure(...)`: Free tile from occupancy

### 3. BuildPieceFactory
Structure blueprint definitions and metadata creation:
- **Structure Types**:
  - **Floor**: Horizontal platform (tileSize × tileSize)
    - Supports structures above
    - Requires support below
    - Units can walk on it
  - **Wall**: Vertical barrier on tile edge (tileSize × wallHeight)
    - Supports structures above
    - Requires support below
    - Blocks unit passage
    - Edge-aligned (not center-aligned)
  - **Ramp**: Inclined surface for vertical traversal
    - Rises over wallHeight
    - No collision plate underneath
    - Requires support below
    - Cannot support structures directly above

**Key Methods:**
- `GetBlueprint(structureType)`: Get structure blueprint
- `CreateStructureMetadata(...)`: Create structure with full metadata
- `RequiresSupport(structureType)`: Check if type needs support
- `CanSupportAbove(structureType)`: Check if type can support others

### 4. BuildSupportService
Support validation and cascade destruction:
- **Support Rules**:
  - Ground level (level 0) has terrain support
  - Structures can be supported by floors or walls below them
  - Walls can be placed on floors at the same level
  
- **Dependency Tracking**: Maintains graph of which structures support which
- **Cascade Destruction**: BFS algorithm to find all unsupported structures when support is removed

**Key Methods:**
- `HasValidSupport(gridX, gridZ, level, structureType)`: Check if position has support
- `RegisterStructure(metadata)`: Add structure to dependency graph
- `UnregisterStructure(structureId)`: Remove from dependency graph
- `CalculateCascadeDestruction(removedStructureId)`: Find all structures to destroy

### 5. BuildPlacementService
High-level placement interface and validation:
- **Placement Validation**: Multi-stage validation (type, rotation, overlap, support)
- **Preview System**: Create placement previews with validation feedback
- **Placement Flow**: Validate → Create Metadata → Occupy Grid → Register Dependencies
- **Removal Flow**: Remove from Grid → Calculate Cascade → Remove Dependents

**Key Methods:**
- `ValidatePlacement(...)`: Validate structure placement
- `PlaceStructure(...)`: Place a structure (returns success, message, metadata)
- `RemoveStructure(...)`: Remove structure and handle cascade
- `CreatePreview(...)`: Create placement preview for UI
- `GetStructuresInArea(...)`: Query nearby structures

## Grid System

### Coordinate System
- **Grid Coordinates**: Integer-based (gridX, gridZ, level)
- **World Coordinates**: Roblox world position (worldX, worldY, worldZ)
- **Snapping**: All structures snap to grid alignment

### Placement Rules
1. **No Overlaps**: Cannot place structures at occupied grid positions
2. **Support Required**: All structures (except at ground level) must have support
3. **Rotation Constraints**: Only 0°, 90°, 180°, 270° allowed
4. **Valid Structure Type**: Must be Floor, Wall, or Ramp

### Support System
```
Level 2: [Floor] ← Supported by Level 1 Floor
         └─────┘
Level 1: [Floor] ← Supported by Level 0 Floor
         └─────┘
Level 0: [Floor] ← Supported by Terrain
         └─────┘
Terrain: ========
```

## Usage Example

```lua
-- Initialize the building system
local BuildingSystem = require(script.BuildingSystem.BuildingSystemInit)
local system = BuildingSystem.Initialize()

-- Get services
local placement = system.PlacementService
local config = system.Config

-- Place a floor at ground level
local success, message, metadata = placement:PlaceStructure(
    config.StructureType.Floor,
    0, 0,    -- world X, Z
    0,       -- level (ground)
    0,       -- rotation
    "Wood"   -- material
)

if success then
    print("Placed structure:", metadata.Id)
    print("HP:", metadata.CurrentHP, "/", metadata.MaxHP)
end

-- Create a preview for validation
local preview = placement:CreatePreview(
    config.StructureType.Wall,
    4, 4,
    0,
    90,
    "Stone"
)

print("Preview valid:", preview.IsValid)
if not preview.IsValid then
    print("Error:", preview.ValidationResult.ErrorMessage)
end

-- Remove structure and handle cascade
local gridX, gridZ = system.GridService:WorldToGrid(0, 0)
success, message, result = placement:RemoveStructure(
    gridX, gridZ, 0, 
    config.StructureType.Floor
)

if success then
    print("Removed:", result.RemovedStructure.Id)
    print("Cascade destroyed:", #result.CascadeDestroyed, "structures")
end
```

## Structure Metadata

Each structure contains:
```lua
{
    -- Identity
    Id = "unique_id",
    Type = "Floor|Wall|Ramp",
    
    -- Grid position
    GridX = 0,
    GridZ = 0,
    Level = 0,
    Rotation = 0,
    
    -- Material/Tier
    Material = "Wood",
    MaxHP = 100,
    CurrentHP = 100,
    
    -- State
    IsPlaced = true,
    PlacedTime = timestamp,
    
    -- Support tracking
    SupportedBy = {},  -- List of structure IDs
    Supporting = {}    -- List of structure IDs
}
```

## Validation Errors

The system provides clear error messages for invalid placements:
- `"Structure must be supported (no floating builds allowed)"`: Missing support
- `"Cannot place structure here - position already occupied"`: Overlap detected
- `"Invalid rotation angle - must be 0, 90, 180, or 270 degrees"`: Bad rotation
- `"Invalid structure type specified"`: Unknown structure type

## Future Enhancements

The system is designed to be extensible for:
- **Physics Integration**: Replace simplified support with actual physics
- **Damage System**: Integrate HP with combat mechanics
- **Visual Feedback**: Add preview rendering and build effects
- **Network Replication**: Add server-client synchronization
- **Build Permissions**: Add player/team ownership
- **Resource Costs**: Add material gathering and costs
- **Build Limits**: Add per-player build limits

## Testing

See `ExampleUsage.lua` for comprehensive testing of all features:
- Floor placement at ground level
- Wall placement on floors
- Multi-level floor stacking
- Invalid placement attempts (no support, overlaps)
- Ramp placement
- Preview system
- Cascade destruction
- Coordinate conversion
- Area queries

## Notes

- This is an MVP implementation with simplified terrain support
- All structures require deterministic support (no floating builds)
- Cascade destruction uses BFS to find all dependent structures
- The system is fully modular and can be integrated with other game systems
- No AI or NPC logic is included (by design)
