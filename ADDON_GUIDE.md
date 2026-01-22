# SaucedCarts Addon Guide

This guide explains how to create addon mods that add custom cart types to SaucedCarts.

## Table of Contents

1. [Quick Start](#quick-start)
2. [How It Works](#how-it-works)
3. [File Structure](#file-structure)
4. [Registration API](#registration-api)
5. [API Stability](#api-stability)
6. [Custom Visual States](#custom-visual-states)
7. [Item Definitions](#item-definitions)
8. [Model Definitions](#model-definitions)
9. [Attachment Tweaker](#attachment-tweaker-model-positioning-tool)
10. [Assets](#assets)
11. [Animations](#animations)
12. [Spawn Locations](#spawn-locations)
13. [Container Restrictions](#container-restrictions)
14. [Repair System](#repair-system)
15. [Testing](#testing)
16. [Troubleshooting](#troubleshooting)

---

## Quick Start

The fastest way to get started:

1. **Copy the template**: Copy `docs/ADDON_TEMPLATE/` to your PZ mods folder
2. **Rename everything**: Replace "MyCartAddon" with your mod name in all files
3. **Add your assets**: Replace placeholder files with your 3D model and textures
4. **Test in-game**: Enable your mod and use `SaucedCartsDebug.listRegistered()` to verify

That's it! Your cart will automatically work with SaucedCarts' pickup, drop, and context menu systems.

---

## How It Works

SaucedCarts provides all the cart functionality - you just need to:

1. **Define the item** - Tell PZ about your cart (items_*.txt)
2. **Define the model** - Map your 3D assets (models_*.txt)
3. **Register with SaucedCarts** - Tell SaucedCarts about your cart (init.lua)

Once registered, your cart automatically gets:
- Right-click context menu "Push Cart" option (dropping uses vanilla "Drop")
- Two-handed equipping with proper animations
- Container storage with weight reduction
- Condition/durability system
- World spawning (if you specify spawn locations)
- Multiplayer synchronization

---

## File Structure

Your addon mod should have this structure:

```
YourModName/
├── mod.info                              # Mod metadata
├── media/
│   ├── scripts/
│   │   ├── items_yourmod.txt             # Item definitions
│   │   └── models_yourmod.txt            # Model mappings
│   ├── lua/shared/YourModName/
│   │   └── init.lua                      # Registration code
│   ├── textures/
│   │   ├── Item_YourCart.png             # Inventory icon (32x32)
│   │   └── weapons/2handed/
│   │       └── yourcart.png              # Model texture (512x512)
│   └── models_X/weapons/2handed/
│       └── yourcart.fbx                  # 3D model
```

### mod.info

```
name=Your Mod Name
id=YourModName
description=Adds custom carts using SaucedCarts.
poster=poster.png
modversion=1.0.0
versionmin=42.13.1
require=SaucedCarts
```

**Important**: The `require=SaucedCarts` line ensures SaucedCarts loads before your mod.

---

## Registration API

### Basic Registration

```lua
local success, err = SaucedCarts.registerCart("YourMod.YourCart", {
    name = "Your Cart Name",  -- REQUIRED: Display name
})
```

### Full Registration (All Options)

```lua
SaucedCarts.registerCart("YourMod.YourCart", {
    -- REQUIRED
    name = "Your Cart Name",

    -- OPTIONAL (with defaults shown)
    description = "",                    -- Flavor text for tooltips
    capacity = 50,                       -- Storage capacity (units)
    weightReduction = 90,                -- Weight reduction % (90 = items weigh 10%)
    runSpeedModifier = 0.75,             -- Movement speed (0.75 = 75% speed)
    conditionMax = 100,                  -- Maximum durability
    baseWeight = 5.0,                    -- Empty cart weight (kg)
    repairItem = "Base.ScrapMetal",      -- Item used for repairs
    repairAmount = 10,                   -- Condition restored per repair
    spawnRooms = {},                     -- Room-based world spawning (see Spawn Locations)
})
```

### Field Reference

| Field | Type | Default | Valid Range | Description |
|-------|------|---------|-------------|-------------|
| `name` | string | (required) | - | Display name in UI |
| `description` | string | "" | - | Tooltip flavor text |
| `capacity` | number | 50 | 1-1000 | Storage capacity |
| `weightReduction` | number | 90 | 0-100 | Weight reduction % |
| `runSpeedModifier` | number | 0.75 | 0.01-2.0 | Movement speed multiplier |
| `conditionMax` | number | 100 | 1-1000 | Maximum durability |
| `baseWeight` | number | 5.0 | 0.1-500 | Empty weight in kg |
| `repairItem` | string | "Base.ScrapMetal" | Module.Item format | Repair material |
| `repairAmount` | number | 10 | 1-100 | Base condition per repair |
| `repairSkill` | Perk | nil | Perk userdata | Skill for repair bonus (nil = Maintenance) |
| `repairSkillBonus` | number | 1 | 0-10 | +condition per skill level |
| `repairTimeBase` | number | 100 | 10-500 | Base repair duration in ticks |
| `repairXpGain` | number | 3 | 0-50 | XP awarded per repair |
| `spawnRooms` | table | {} | array of {room, chance} | World spawn locations (see below) |
| `visualModels` | table | nil | {empty, partial, full} | Custom models for fill states (see below) |

### Return Values

```lua
local success, err = SaucedCarts.registerCart(...)

if success then
    print("Cart registered!")
else
    print("Failed: " .. err)
end
```

### Load Order Safety

If your mod might load before SaucedCarts (shouldn't happen with `require=`), use this pattern:

```lua
if SaucedCarts and SaucedCarts.registerCart then
    -- Direct registration
    SaucedCarts.registerCart("YourMod.Cart", data)
else
    -- Queue for later
    SaucedCarts = SaucedCarts or {}
    SaucedCarts._pendingRegistrations = SaucedCarts._pendingRegistrations or {}
    table.insert(SaucedCarts._pendingRegistrations, {
        fullType = "YourMod.Cart",
        data = data
    })
end
```

---

## API Stability

SaucedCarts provides stability guarantees for addon developers.

### Version Constants

```lua
SaucedCarts.VERSION       -- Mod version (e.g., "1.0.0")
SaucedCarts.API_VERSION   -- Registration API version (integer, e.g., 1)
SaucedCarts.SCHEMA_VERSION -- ModData schema version (integer)
```

- **API_VERSION** increments on breaking changes (field renames, removed fields, signature changes)
- **VERSION** follows semantic versioning for the mod itself
- **SCHEMA_VERSION** tracks ModData format changes (handled internally)

### Checking API Version

```lua
if SaucedCarts.API_VERSION >= 1 then
    -- Use API features introduced in version 1
    SaucedCarts.registerCart("MyMod.Cart", { ... })
end
```

### Guaranteed Stable

These parts of the API will not change without an API_VERSION increment:

- `SaucedCarts.registerCart()` - signature and return type
- All documented fields in registration (`name`, `capacity`, `visualModels`, etc.)
- `SaucedCarts.isCart()`, `isRegistered()`, `getCartData()` functions
- Load order safety via `_pendingRegistrations` queue
- Validation rules and error message format

### May Change Without Notice

These are internal implementation details:

- Range limits on numeric fields (may be expanded, not shrunk)
- Debug output format and messages
- Undocumented functions (local functions, `_` prefixed globals)
- Internal ModData field names (use API accessors instead)
- **Developer tools** (`SaucedCartsTweaker`, `SaucedCartsDebug`) - helpful but not stable

---

## Custom Visual States

SaucedCarts supports dynamic visual models that change based on how full the cart is. Your addon cart can have three different models: empty, partially full, and completely full.

### How It Works

When items are added to or removed from a cart, SaucedCarts calculates the fill percentage:

| Fill State | Fill Percentage | Model Used |
|------------|-----------------|------------|
| `empty` | 0-32% | Base model (e.g., `YourCartModel`) |
| `partial` | 33-65% | Partial model (e.g., `YourCartPartialModel`) |
| `full` | 66-100% | Full model (e.g., `YourCartFullModel`) |

### Registering Custom Visual Models

Add `visualModels` to your registration to specify your cart's fill state models:

```lua
SaucedCarts.registerCart("YourMod.YourCart", {
    name = "Your Cart",
    visualModels = {
        empty = "YourCartModel",
        partial = "YourCartPartialModel",
        full = "YourCartFullModel",
    },
})
```

### Creating the Models

You need to define three models in your `models_yourmod.txt`:

```lua
module Base
{
    -- Empty cart model (0-32% full)
    model YourCartModel
    {
        mesh = weapons/2handed/yourcart_empty|submesh,
        texture = weapons/2handed/yourcart,
        scale = 0.3,
        invertX = true,
        attachment world { offset = 0.0 0.0 0.0, rotate = 0.0 90.0 0.0 }
    }

    -- Partially full cart model (33-65% full)
    model YourCartPartialModel
    {
        mesh = weapons/2handed/yourcart_partial|submesh,
        texture = weapons/2handed/yourcart,
        scale = 0.3,
        invertX = true,
        attachment world { offset = 0.0 0.0 0.0, rotate = 0.0 90.0 0.0 }
    }

    -- Full cart model (66%+ full)
    model YourCartFullModel
    {
        mesh = weapons/2handed/yourcart_full|submesh,
        texture = weapons/2handed/yourcart,
        scale = 0.3,
        invertX = true,
        attachment world { offset = 0.0 0.0 0.0, rotate = 0.0 90.0 0.0 }
    }
}
```

### Fallback Behavior

If you don't specify `visualModels`, SaucedCarts attempts **convention-based naming**:

1. Gets your item's `StaticModel` from items_*.txt (e.g., `WheelbarrowModel`)
2. Strips the "Model" suffix to get base name (e.g., `Wheelbarrow`)
3. Builds fill state names: `WheelbarrowModel`, `WheelbarrowPartialModel`, `WheelbarrowFullModel`

For best results, **always specify `visualModels` explicitly** - it's more reliable and documents your intent.

### Single Model (No Fill States)

If you only want one model regardless of fill state, specify the same model for all states:

```lua
visualModels = {
    empty = "YourCartModel",
    partial = "YourCartModel",
    full = "YourCartModel",
},
```

### MP Synchronization

Visual states are automatically synchronized in multiplayer:
- When you add/remove items, your client updates immediately for responsiveness
- The server syncs the visual state to all nearby players
- Self-correction runs every ~1 second to fix any drift

---

## Item Definitions

Create `media/scripts/items_yourmod.txt`:

```lua
module YourModName
{
    imports {Base}

    item YourCart
    {
        -- Container settings (REQUIRED)
        DisplayCategory = Container,
        Type = Container,

        -- Display
        DisplayName = Your Cart Name,
        Icon = YourCart,

        -- Container stats (should match registration)
        Capacity = 50,
        WeightReduction = 90,

        -- Physical stats
        Weight = 5.0,
        RunSpeedModifier = 0.75,

        -- Durability
        ConditionMax = 100,
        ConditionLowerChance = 25,

        -- CRITICAL: Required for two-handed equip
        RequiresEquippedBothHands = true,

        -- Sounds
        CloseSound = CloseBag,
        OpenSound = OpenBag,
        PutInSound = PutItemInBag,

        -- Model connections (must match models_*.txt)
        ReplaceInPrimaryHand = YourCartModel holdingcartright,
        ReplaceInSecondHand = YourCartModel holdingcartleft,
        StaticModel = YourCartModel,
        WorldStaticModel = YourCartModel,

        -- Tags
        Tags = SaucedCart,
    }
}
```

### Critical Fields

- `Type = Container` - Makes the item a container
- `RequiresEquippedBothHands = true` - Enables two-handed equip
- `ReplaceInPrimaryHand` / `ReplaceInSecondHand` - Connects to animations

---

## Model Definitions

Create `media/scripts/models_yourmod.txt`:

```lua
module Base
{
    model YourCartModel
    {
        mesh = weapons/2handed/yourcart|submeshname,
        texture = weapons/2handed/yourcart,
        scale = 0.3,
        invertX = true,

        attachment world
        {
            offset = 0.0000 0.0000 0.0000,
            rotate = 0.0000 90.0000 0.0000,
        }
    }
}
```

**Important**: Models MUST be in the `Base` module, not your mod's module!

### Mesh Path Format

```
mesh = folder/file|submeshname
```

- `folder/file` - Path relative to `models_X/` without extension
- `submeshname` - The object name from your Blender file (after the `|` pipe)

### Attachment Tweaker (Model Positioning Tool)

SaucedCarts includes a real-time debug tool for adjusting model attachment offset, rotation, and scale while holding your cart in-game. This eliminates the edit-reload-test cycle.

> **Note:** This tool is provided as-is for developer convenience. It may change between versions and is not covered by API stability guarantees.

#### Basic Usage

1. Equip your cart in-game (debug mode)
2. Run: `SaucedCartsTweaker.enable()`
3. Use keybinds to adjust position/rotation
4. Run: `SaucedCartsTweaker.print()` to get copy-paste values
5. Run: `SaucedCartsTweaker.disable()` when done

#### Keybinds (while enabled)

| Action | Numpad | Alternative |
|--------|--------|-------------|
| **Offset X** (height up/down) | 7 / 9 | U / O |
| **Offset Y** (forward/back) | 4 / 6 | J / L |
| **Offset Z** (lateral) | 1 / 3 | M / . |
| **Rotate X** (pitch) | - | Insert / Delete |
| **Rotate Y** (yaw/turn) | - | Home / End |
| **Rotate Z** (roll/tilt) | - | PageUp / PageDown |
| **Scale** | * / / | ] / [ |
| **Step size** | + / - | = / - |
| **Print values** | 0 | P |
| **Toggle HUD** | . | H |

#### Commands

```lua
SaucedCartsTweaker.enable()              -- Start tweaking held item
SaucedCartsTweaker.disable()             -- Stop, print final values
SaucedCartsTweaker.print()               -- Print current values
SaucedCartsTweaker.set(x,y,z,rx,ry,rz,s) -- Set all values directly
SaucedCartsTweaker.reset()               -- Reset to model file values
```

#### Workflow

1. Get your model roughly positioned in `models_yourmod.txt`
2. Load the game and equip your cart
3. Enable the tweaker and adjust until it looks right
4. Copy the printed values back to your model file:

```lua
-- Output from SaucedCartsTweaker.print():
attachment world
{
    offset = 0.1200 -0.0500 0.0000,
    rotate = 0.0 95.0 -5.0,
    scale = 0.2800,
}
```

#### Axis Reference

| Axis | Effect |
|------|--------|
| Offset X | Height (up = positive, down = negative) |
| Offset Y | Forward/backward (away from player = positive) |
| Offset Z | Lateral (left/right) |
| Rotate Y | Yaw - turn cart around |
| Rotate Z | Roll - tilt to level the cart |

---

## Assets

### 3D Model (FBX)

Location: `media/models_X/weapons/2handed/yourcart.fbx`

Requirements:
- Format: FBX (2014+)
- Scale: Game scale (~1 unit = 1 meter)
- Origin: Center-bottom of cart
- Forward: +Y axis

Blender Export Settings:
- Scale: 1.0
- Forward: -Z Forward
- Up: Y Up
- Apply Modifiers: Yes
- Apply Transform: Yes

### Model Texture (PNG)

Location: `media/textures/weapons/2handed/yourcart.png`

Requirements:
- Size: 512x512 or 1024x1024
- Format: PNG
- UV mapping must match your FBX model

### Inventory Icon (PNG)

Location: `media/textures/Item_YourCart.png`

Requirements:
- Size: 32x32 (or 64x64 for high-res)
- Format: PNG with transparency
- Style: Top-down view, PZ style

---

## Animations

### Default: Reuse SaucedCarts Animations

Your cart automatically uses SaucedCarts' cart animations. This is the recommended approach - it's simpler and ensures consistent behavior.

The animation variables are set automatically:
- `holdingcartright` - Right hand position
- `holdingcartleft` - Left hand position

### Custom Animations (Advanced)

If you need different animations (e.g., wheelbarrow with different push pose):

1. Create animation files in `media/anims_X/Bob/`
2. Create AnimSet XMLs in `media/AnimSets/player/`
3. Modify `ReplaceInPrimaryHand` / `ReplaceInSecondHand` in items_*.txt

This requires significant knowledge of PZ's animation system. For detailed guidance, see:

- `docs/ANIMSET_GUIDE.md` - Tutorial for creating AnimSets
- `docs/ANIMSET_SYSTEM.md` - System overview and `x_extends` inheritance
- `docs/ANIMATION_XML_REFERENCE.md` - Technical reference for all XML elements

### Using x_extends for Custom Cart AnimSets

If creating custom AnimSets that extend vanilla animations, you must copy the parent files locally because PZ resolves `x_extends` paths relative to your mod's directory.

**Required Structure:**
```
YourMod/
└── media/AnimSets/player/
    ├── idle/
    │   ├── Idle.xml           # Copy from vanilla (for x_extends to work)
    │   └── idle_yourcart.xml  # Your custom idle state
    ├── movement/
    │   ├── defaultWalk.xml    # Copy from vanilla
    │   └── walk_yourcart.xml  # Your custom walk state
    ├── run/
    │   ├── defaultRun.xml     # Copy from vanilla
    │   └── run_yourcart.xml   # Your custom run state
    └── sprint/
        ├── defaultSprint.xml  # Copy from vanilla
        └── sprint_yourcart.xml # Your custom sprint state
```

### Critical: 2D Blend Configuration

> **⚠️ WARNING**: When overriding `m_2DBlends` in your AnimSet XMLs, you MUST include all required properties or movement will be extremely slow!

**WRONG** (causes MoveSpeed to be stuck at 0.06):
```xml
<m_2DBlends>
    <m_AnimName>Bob_YourCart_Walk</m_AnimName>
</m_2DBlends>
```

**CORRECT** (normal movement speed):
```xml
<m_2DBlends referenceID="1">
    <m_AnimName>Bob_YourCart_Walk</m_AnimName>
    <m_XPos>0.00</m_XPos>
    <m_YPos>0.00</m_YPos>
    <m_SpeedScale>0.80</m_SpeedScale>
</m_2DBlends>
```

Each blend node requires:
- `referenceID` - Must match parent AnimSet's blend count
- `m_XPos`, `m_YPos` - Position in 2D blend space
- `m_SpeedScale` - Animation speed multiplier

### Example: Custom Walk AnimSet

```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode x_extends="defaultWalk.xml">
    <m_Name>walkYourCart</m_Name>
    <m_AnimName>Bob_YourCart_Walk</m_AnimName>
    <m_SpeedScale>1.0</m_SpeedScale>

    <!-- Must match defaultWalk.xml's 6 blend nodes -->
    <m_2DBlends referenceID="1">
        <m_AnimName>Bob_YourCart_Walk</m_AnimName>
        <m_XPos>0.50</m_XPos>
        <m_YPos>1.00</m_YPos>
        <m_SpeedScale>0.80</m_SpeedScale>
    </m_2DBlends>
    <m_2DBlends referenceID="2">
        <m_AnimName>Bob_YourCart_Walk</m_AnimName>
        <m_XPos>-0.50</m_XPos>
        <m_YPos>1.00</m_YPos>
        <m_SpeedScale>0.80</m_SpeedScale>
    </m_2DBlends>
    <m_2DBlends referenceID="3">
        <m_AnimName>Bob_YourCart_Walk</m_AnimName>
        <m_XPos>1.00</m_XPos>
        <m_YPos>1.00</m_YPos>
        <m_SpeedScale>0.80</m_SpeedScale>
    </m_2DBlends>
    <m_2DBlends referenceID="4">
        <m_AnimName>Bob_YourCart_Walk</m_AnimName>
        <m_XPos>-1.00</m_XPos>
        <m_YPos>1.00</m_YPos>
        <m_SpeedScale>0.80</m_SpeedScale>
    </m_2DBlends>
    <m_2DBlends referenceID="5">
        <m_AnimName>Bob_YourCart_Walk</m_AnimName>
        <m_XPos>0.00</m_XPos>
        <m_YPos>1.00</m_YPos>
        <m_SpeedScale>0.80</m_SpeedScale>
    </m_2DBlends>
    <m_2DBlends referenceID="6">
        <m_AnimName>Bob_YourCart_Walk</m_AnimName>
        <m_XPos>0.00</m_XPos>
        <m_YPos>0.00</m_YPos>
        <m_SpeedScale>0.80</m_SpeedScale>
    </m_2DBlends>

    <!-- Trigger condition: Weapon variable = "yourcart" -->
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_Value>yourcart</m_Value>
    </m_Conditions>

    <!-- Transitions to other cart states -->
    <m_Transitions>
        <m_Target>IdleYourCart</m_Target>
        <m_blendInTime>0.3</m_blendInTime>
    </m_Transitions>
    <m_Transitions>
        <m_Target>runYourCart</m_Target>
        <m_blendInTime>0.3</m_blendInTime>
    </m_Transitions>
    <m_Transitions>
        <m_Target>sprintYourCart</m_Target>
        <m_blendInTime>0.5</m_blendInTime>
    </m_Transitions>
</animNode>
```

### Setting Your Custom Animation Variable

In your addon's Lua code, set the Weapon variable to trigger your custom animations:

```lua
-- When equipping your custom cart
player:setVariable("Weapon", "yourcart")

-- When unequipping
player:setVariable("Weapon", "")
```

### Root Motion (Animation-Driven Movement)

If your custom animations need to drive character movement (like pushing a cart), you need to understand PZ's **deferred movement** system.

#### How It Works

PZ extracts movement from a special bone called `Translation_Data`. Each frame, the bone's position delta is applied as character movement.

**Java Source Reference** (AnimationTrack.java:324-329):
```java
private Vector2 getDeferredMovement(Vector3f bonePos, Vector2 out_deferredPos) {
    if (this.deferredBoneAxis == BoneAxis.Y) {
        out_deferredPos.set(bonePos.x, -bonePos.z);  // Forward = -Z axis
    } else {
        out_deferredPos.set(bonePos.x, bonePos.y);   // Forward = Y axis
    }
}
```

#### Creating the Translation_Data Bone in Blender

1. Add a new bone named exactly `Translation_Data` to your armature
2. Parent it to the root bone (or leave unparented)
3. Animate it moving forward over the walk/run cycle:
   - **Keyframe 0**: Position (0, 0, 0)
   - **Last keyframe**: Position (0, distance_traveled, 0) for Y-forward

The bone should move the distance the character would travel during one animation loop.

#### Setting deferredBoneAxis

The `m_deferredBoneAxis` XML setting determines which bone axis is read as forward:

| Setting | Reads As Forward | Use When |
|---------|-----------------|----------|
| `Y` (default) | `-bonePos.z` | Animation bone moves on -Z axis |
| `Z` | `bonePos.y` | Animation bone moves on Y axis (Blender default) |

**For Blender Y-forward animations**, use:
```xml
<m_deferredBoneAxis>Z</m_deferredBoneAxis>
```

**For -Z forward animations** (or imported vanilla animations), use:
```xml
<m_deferredBoneAxis>Y</m_deferredBoneAxis>
```

#### Complete AnimSet Example with Root Motion

```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode>
    <m_Name>walkYourCart</m_Name>
    <m_AnimName>Bob_YourCart_Walk</m_AnimName>
    <m_SpeedScale>1.04</m_SpeedScale>
    <m_deferredBoneAxis>Z</m_deferredBoneAxis>  <!-- For Blender Y-forward -->

    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_Value>yourcart</m_Value>
    </m_Conditions>

    <m_Transitions>
        <m_Target>IdleYourCart</m_Target>
        <m_blendInTime>0.3</m_blendInTime>
    </m_Transitions>
</animNode>
```

#### Troubleshooting Root Motion

| Problem | Cause | Solution |
|---------|-------|----------|
| Character doesn't move | Missing Translation_Data bone | Add the bone to your animation |
| Character rotates/falls over | Wrong `m_deferredBoneAxis` | Switch between `Y` and `Z` |
| Movement too slow/fast | Bone travel distance wrong | Adjust bone keyframe positions |
| Sliding/skating effect | Animation speed vs bone speed mismatch | Adjust `m_SpeedScale` |

#### SaucedCarts Reference

SaucedCarts cart animations use `m_deferredBoneAxis=Z` because they were created in Blender with Y-forward convention. The Translation_Data bone moves along the Y axis during walk/run/sprint cycles.

For complete technical details on root motion, see `docs/ANIMATION_XML_REFERENCE.md` section "m_deferredBoneAxis (Root Motion)".

---

## Spawn Locations

SaucedCarts uses **world spawning** - carts spawn on the ground in appropriate locations (stores, warehouses) rather than inside containers.

> **Container Restrictions**: Carts can only be stored in:
> - The ground (dropped)
> - Player's main inventory (when equipped)
> - Vehicle containers (trunk, glovebox)
>
> Carts **cannot** go in bags, backpacks, or furniture containers.

### How It Works

- Carts spawn on the floor when a building is first loaded
- One cart per building maximum (prevents spam)
- Spawn chance is per-room-type (e.g., 50% in gigamarts)
- Server-authoritative for multiplayer sync

### Configuring Spawn Rooms

Add `spawnRooms` to your registration with room names and spawn chances:

```lua
SaucedCarts.registerCart("YourMod.Cart", {
    name = "Your Cart",
    spawnRooms = {
        { room = "farmstorage", chance = 40 },  -- 40% chance in farm storage
        { room = "garage", chance = 20 },       -- 20% chance in garages
        { room = "shed", chance = 30 },         -- 30% chance in sheds
    },
})
```

### spawnRooms Format

Each entry is a table with:
- `room` (string): PZ room name (from building definitions)
- `chance` (number): Spawn probability 0-100 (percentage)

### Common Room Names

| Room Name | Location Type |
|-----------|---------------|
| `gigamart` | Large grocery stores (Gigamart) |
| `grocery` | Standard grocery stores |
| `supermarket` | Supermarkets |
| `departmentstore` | Department stores |
| `warehouse` | Warehouses |
| `toolstore` | Hardware/tool stores |
| `gardenstore` | Garden centers |
| `bookstore` | Bookstores |
| `clothingstore` | Clothing stores |
| `electronicsstore` | Electronics stores |
| `conveniencestore` | Convenience stores |
| `farmstorage` | Farm storage buildings |
| `garage` | Garages |
| `shed` | Sheds |
| `barn` | Barns |

### Finding Room Names

To find room names for a specific building:
1. Enable debug mode in PZ
2. Stand in the room
3. Use Lua console: `print(getPlayer():getCurrentSquare():getRoom():getName())`

### No Spawns

Empty `spawnRooms = {}` means no world spawns - players must craft or obtain the cart another way.

---

## Container Restrictions

SaucedCarts enforces strict rules about where carts can be stored to maintain game balance and prevent exploits.

### Allowed Destinations

| Location | Example |
|----------|---------|
| Ground | Dropped on floor/terrain |
| Player's main inventory | When equipped in hands |
| Vehicle containers | Car trunk, glovebox |

### Blocked Destinations

Carts **cannot** be placed in:

- Bags and backpacks
- Furniture containers (crates, shelves, dressers)
- Other carts (no nested carts)
- World containers (wardrobes, filing cabinets)

### What Happens

When a player tries to put a cart somewhere it's not allowed:

1. **Drag-and-drop**: The operation is silently blocked
2. **Context menu**: "Grab" options are hidden for invalid destinations
3. **Server validation**: Even if bypassed client-side, the server rejects the transfer

This is server-authoritative - the restriction cannot be bypassed.

### Design Rationale

This prevents:
- Infinite storage exploits (cart in bag in cart...)
- Weight bypass abuse (bag weight reduction stacking with cart)
- Gameplay trivializing (carrying dozens of carts in a backpack)

### For Addon Developers

Your addon carts automatically inherit these restrictions - no additional code needed. The `SaucedCarts.isCart()` function includes your registered cart types.

---

## Repair System

Carts degrade over time and can be repaired.

### How Condition Works

- **ConditionMax**: Maximum durability (from registration, scaled by sandbox multiplier)
- **Condition**: Current durability (0 = broken)
- **ConditionLowerChance**: How often condition drops (from items_*.txt)

Condition degrades based on distance pushed. When a cart is picked up, accumulated distance is converted to wear. A cart at 0 condition breaks and drops all items.

### Repair Mechanics

To repair a cart:

1. Player needs the `repairItem` (default: `Base.ScrapMetal`)
2. Right-click the cart → "Repair Cart"
3. Repair is a timed action (duration based on `repairTimeBase` and skill)
4. Each repair restores `repairAmount` + skill bonus condition
5. Material is consumed on successful repair
6. XP is awarded based on `repairXpGain` (when skill bonus enabled)
7. Multiple repairs may be needed for full restoration

**Repair Material Sources**: Materials can be in the player's inventory OR inside the cart itself. This allows players to stockpile repair materials in their cart.

**Repair Context**: The repair option appears for both:
- Ground carts (right-click on cart in world)
- Inventory carts (right-click cart in inventory panel)

### Skill Integration

By default, the Maintenance skill affects repairs:

- **Repair Amount**: `base + (skillLevel * repairSkillBonus)`
- **Repair Time**: Reduced by 5 ticks per skill level (max 50% reduction)
- **XP Award**: `repairXpGain` XP per successful repair

This can be disabled via sandbox option `MaintenanceSkillBonus`.

### Configuring for Your Cart

```lua
SaucedCarts.registerCart("YourMod.Cart", {
    name = "Your Cart",
    conditionMax = 100,                  -- Maximum durability
    repairItem = "Base.ScrapMetal",      -- Item consumed for repair
    repairAmount = 10,                   -- Base condition restored per repair
    repairSkill = nil,                   -- nil = Perks.Maintenance (default)
    repairSkillBonus = 1,                -- +1 condition per skill level
    repairTimeBase = 100,                -- Base duration in ticks
    repairXpGain = 3,                    -- XP per repair
})
```

### Custom Skill for Repair

You can use a different skill for specialized carts:

```lua
-- A wooden cart repaired with Carpentry skill
SaucedCarts.registerCart("YourMod.WoodenCart", {
    name = "Wooden Cart",
    repairItem = "Base.Plank",
    repairSkill = Perks.Woodwork,        -- Uses Carpentry skill
    repairSkillBonus = 2,                -- +2 per Carpentry level
    repairXpGain = 5,                    -- Award 5 Carpentry XP
})
```

### Custom Repair Items

You can use any valid item type:

```lua
repairItem = "Base.Plank",           -- For wooden carts
repairItem = "Base.MetalPipe",       -- For metal carts
repairItem = "YourMod.SpecialPart",  -- Your custom item
```

The format must be `Module.ItemName`.

### Sandbox Options for Repair

Server admins can adjust repair via sandbox settings:

| Setting | Default | Effect |
|---------|---------|--------|
| `RepairAmountMultiplier` | 100 | Scale repair amount (200 = double) |
| `RepairTimeMultiplier` | 100 | Scale repair time (50 = faster) |
| `MaintenanceSkillBonus` | true | Enable skill bonuses and XP |

### Testing Repairs

Debug commands for testing the repair system:

```lua
-- Set cart condition to specific percentage (0-100)
SaucedCartsDebug.setCondition(50)

-- Give repair materials to player inventory
SaucedCartsDebug.giveRepairMaterial()      -- 5x Base.ScrapMetal (default)
SaucedCartsDebug.giveRepairMaterial(10)    -- 10x Base.ScrapMetal
SaucedCartsDebug.giveRepairMaterial(5, "Base.Plank")  -- 5x Wood Plank

-- Instantly repair held cart (bypasses timed action)
SaucedCartsDebug.repairCart()
```

---

## Testing

### Debug Commands

In the Lua console (debug mode or admin):

> **Note:** Debug commands are developer tools and may change between versions. They are not covered by API stability guarantees.

#### Registration & Spawning

```lua
-- List all registered cart types with details
SaucedCartsDebug.listRegistered()

-- Check if specific cart type is registered
SaucedCartsDebug.checkRegistration("YourMod.YourCart")

-- Spawn cart at player position (on ground)
SaucedCartsDebug.spawnCart("YourCart")

-- Give cart directly to player inventory (equips in hands)
SaucedCartsDebug.giveCart("YourCart")

-- Pick up nearby cart using timed action
SaucedCartsDebug.pickupWorldCart()
```

#### Visual State Testing

```lua
-- Show current fill state and model info
SaucedCartsDebug.showVisualStatus()

-- Force set visual state (for testing models)
SaucedCartsDebug.setFillState("empty")    -- or "partial" or "full"

-- Cycle through all states: empty -> partial -> full -> empty
SaucedCartsDebug.cycleFillState()

-- Force recalculate visual from actual contents
SaucedCartsDebug.forceVisualUpdate()
```

#### Condition & Status

```lua
-- Show equipped cart info (fill %, condition, type)
SaucedCartsDebug.showStatus()

-- Set cart condition (0-100)
SaucedCartsDebug.setCondition(50)
```

#### Animation Debugging

```lua
-- Show animator state and key animation variables
SaucedCartsDebug.dumpAnimState()

-- Full animator debug dump (verbose)
SaucedCartsDebug.dumpAnimatorFull()

-- List all condition variables in current AnimSet
SaucedCartsDebug.listAnimVariables()
```

#### Model Positioning (see Attachment Tweaker section)

```lua
-- Start real-time attachment tweaking
SaucedCartsTweaker.enable()

-- Stop tweaking, print final values
SaucedCartsTweaker.disable()

-- Print current values (copy-paste to model file)
SaucedCartsTweaker.print()
```

### Testing Checklist

- [ ] Cart appears in `listRegistered()` output
- [ ] Cart spawns with correct model (`spawnCart`)
- [ ] Cart texture displays correctly
- [ ] Inventory icon shows
- [ ] Cart equips in both hands
- [ ] Cart container opens and holds items
- [ ] Cart drops to ground correctly
- [ ] Cart picks up from ground correctly
- [ ] (If spawns) Cart appears in world containers

---

## Troubleshooting

### Cart not in registered list

**Cause**: Registration code didn't run or failed.

**Fix**:
1. Check mod.info has `require=SaucedCarts`
2. Check init.lua path is correct: `media/lua/shared/YourMod/init.lua`
3. Check for typos in `fullType` (must be "ModuleId.ItemName")
4. Check console for error messages

### "Unknown cart type" error

**Cause**: The fullType doesn't match any registered cart.

**Fix**:
1. Ensure `fullType` in registerCart matches `module.itemname` from items_*.txt
2. Module = mod.info id, ItemName = item block name
3. Example: mod.info `id=MyMod`, item `MyCart` → fullType = `"MyMod.MyCart"`

### Cart spawns but is invisible

**Cause**: Model path is wrong or FBX file is missing/corrupt.

**Fix**:
1. Check `mesh = path|submesh` in models_*.txt matches actual file
2. Verify FBX exists at `media/models_X/weapons/2handed/yourfile.fbx`
3. Check submesh name matches object name in Blender

### Cart has no texture

**Cause**: Texture path is wrong or PNG is missing.

**Fix**:
1. Check `texture = path` in models_*.txt (no extension)
2. Verify PNG exists at `media/textures/weapons/2handed/yourfile.png`
3. Ensure texture is power-of-2 size (512x512 or 1024x1024)

### Cart doesn't equip in both hands

**Cause**: Missing `RequiresEquippedBothHands = true` in items_*.txt.

**Fix**: Add the line to your item definition.

### Registration fails with validation error

**Cause**: Invalid field value.

**Fix**: Check the error message - it tells you exactly what's wrong:
- "must be number, got string" - Wrong type
- "must be between X and Y" - Value out of range
- "must be 'ModuleName.ItemName' format" - Wrong fullType format

### Console spam from SaucedCarts

**Cause**: Debug mode is enabled.

**Fix**: This is normal in debug mode. Disable debug mode for normal play.

---

## Example: Complete Wheelbarrow Addon

### mod.info
```
name=Wheelbarrow Cart
id=WheelbarrowCart
description=Adds a rustic wheelbarrow cart.
modversion=1.0.0
versionmin=42.13.1
require=SaucedCarts
```

### items_wheelbarrow.txt
```lua
module WheelbarrowCart
{
    imports {Base}

    item Wheelbarrow
    {
        DisplayCategory = Container,
        Type = Container,
        DisplayName = Wheelbarrow,
        Icon = Wheelbarrow,
        Capacity = 40,
        WeightReduction = 80,
        Weight = 6.0,
        RunSpeedModifier = 0.80,
        ConditionMax = 80,
        ConditionLowerChance = 30,
        RequiresEquippedBothHands = true,
        CloseSound = CloseBag,
        OpenSound = OpenBag,
        PutInSound = PutItemInBag,
        ReplaceInPrimaryHand = WheelbarrowModel holdingcartright,
        ReplaceInSecondHand = WheelbarrowModel holdingcartleft,
        StaticModel = WheelbarrowModel,
        WorldStaticModel = WheelbarrowModel,
        Tags = SaucedCart,
    }
}
```

### init.lua
```lua
local success, err = SaucedCarts.registerCart("WheelbarrowCart.Wheelbarrow", {
    name = "Wheelbarrow",
    description = "A rustic wooden wheelbarrow for yard work.",
    capacity = 40,
    weightReduction = 80,
    runSpeedModifier = 0.80,
    conditionMax = 80,
    baseWeight = 6.0,
    repairItem = "Base.Plank",
    repairAmount = 15,
    spawnRooms = {
        { room = "gardenstore", chance = 35 },
        { room = "farmstorage", chance = 40 },
        { room = "barn", chance = 30 },
        { room = "shed", chance = 25 },
        { room = "greenhouse", chance = 30 },
    },
    visualModels = {
        empty = "WheelbarrowModel",
        partial = "WheelbarrowPartialModel",
        full = "WheelbarrowFullModel",
    },
})

if success then
    print("[WheelbarrowCart] Registered successfully")
else
    print("[WheelbarrowCart] ERROR: " .. tostring(err))
end
```

---

## Questions?

- Check the SaucedCarts workshop page for updates
- See `ASSET_REQUIREMENTS.md` for detailed 3D asset specifications
- Use `SaucedCartsDebug.testRegistration()` to verify the API works correctly
