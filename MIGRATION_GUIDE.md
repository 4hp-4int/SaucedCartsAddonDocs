#nd  SaucedCarts Migration & Forward Compatibility Guide

This guide explains SaucedCarts' migration system for handling saved game compatibility, orphan cart recovery, and future-proofing against cart type changes.

## Overview

SaucedCarts includes a robust migration system that:

1. **Versions cart ModData** - Tracks schema versions for future upgrades
2. **Handles cart type renames** - Supports type aliases for renamed/moved carts
3. **Recovers orphan carts** - Detects and recovers carts from removed addons
4. **Validates cart state** - Fixes invalid condition values on load
5. **Notifies players** - Warns about missing addon carts with recovery options

## Architecture

```
Core.lua
├── SCHEMA_VERSION = 1
├── TYPE_ALIASES = {}
└── onGameStart() ─────► Migration.migratePlayerInventory()

Migration.lua (shared)
├── looksLikeCart(item)      - Detect potential carts (even orphans)
├── migrateCart(item)        - Per-cart migration logic
├── migratePlayerInventory() - Scan and migrate all carts
├── isOrphan(item)           - Check orphan status
├── recoverOrphanCart()      - Extract items from broken cart
└── getSchemaInfo(item)      - Debug: get migration data

OrphanRecovery.lua (client)
├── notifyOrphans()          - Show warning to player
├── isOrphan(item)           - Check for context menu
└── Context menu handler     - "Recover X items from broken cart"
```

## How It Works

### 1. Schema Versioning

Each cart stores its schema version in ModData:

```lua
local modData = cart:getModData()
modData.SaucedCarts_schemaVersion = 1
modData.SaucedCarts_migratedAt = os.time()
```

When `SCHEMA_VERSION` is bumped, old carts are detected and upgraded:

```lua
if savedVersion < SaucedCarts.SCHEMA_VERSION then
    modData.SaucedCarts_previousVersion = savedVersion
    modData.SaucedCarts_schemaVersion = SaucedCarts.SCHEMA_VERSION
    modData.SaucedCarts_migratedAt = os.time()
end
```

### 2. Type Aliases

When cart types are renamed, add an alias to preserve old carts:

```lua
-- In Core.lua
SaucedCarts.TYPE_ALIASES = {
    ["OldMod.OldCartType"] = "NewMod.NewCartType",
}
```

Migration detects and records the alias:

```lua
modData.SaucedCarts_originalType = "OldMod.OldCartType"
modData.SaucedCarts_aliasedTo = "NewMod.NewCartType"
```

### 3. Orphan Detection

A cart becomes orphaned when:
- Its type is not registered in `SaucedCarts.CartTypes`
- It has no type alias
- It still "looks like" a cart (has SaucedCarts markers)

Detection logic:

```lua
function Migration.looksLikeCart(item)
    -- Must be a container
    if not instanceof(item, "InventoryContainer") then return false end

    -- Check for SaucedCarts module prefix
    if fullType:find("^SaucedCarts%.") then return true end

    -- Check for our ModData markers
    if modData.SaucedCarts_schemaVersion then return true end
    if modData.SaucedCarts_multipliersApplied then return true end

    return false
end
```

### 4. Orphan Recovery

Players can recover items from orphan carts via context menu:

1. Right-click the orphan cart in inventory
2. Select "Recover X items from broken cart"
3. Items transfer to player inventory
4. Broken cart is deleted

The recovery function:

```lua
function Migration.recoverOrphanCart(cart, player)
    local container = cart:getItemContainer()
    local playerInv = player:getInventory()

    -- Transfer items (backwards to avoid index shifting)
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        container:Remove(item)
        playerInv:AddItem(item)
        sendAddItemToContainer(playerInv, item)
    end

    -- Remove broken cart
    playerInv:Remove(cart)
    sendRemoveItemFromContainer(playerInv, cart)
end
```

## ModData Schema Reference

Full ModData structure for migrated carts:

```lua
cart:getModData() = {
    -- Schema versioning
    SaucedCarts_schemaVersion = 1,
    SaucedCarts_previousVersion = 0,      -- Only if upgraded
    SaucedCarts_migratedAt = 1705600000,  -- Unix timestamp

    -- Orphan state (only if cart type missing)
    SaucedCarts_isOrphan = true,
    SaucedCarts_orphanedAt = 1705600000,
    SaucedCarts_orphanedType = "MissingMod.Cart",

    -- Type alias state (only if type was renamed)
    SaucedCarts_originalType = "OldMod.OldCart",
    SaucedCarts_aliasedTo = "NewMod.NewCart",

    -- Restoration state (only if orphan was restored)
    SaucedCarts_restoredAt = 1705600000,

    -- Existing cart state
    SaucedCarts_multipliersApplied = true,
    SaucedCarts_fillState = "empty",
}
```

## Testing the Migration System

### Debug Commands

| Command | Description |
|---------|-------------|
| `SaucedCartsDebug.testMigration()` | Run migration on held cart, show issues |
| `SaucedCartsDebug.makeOrphan()` | Mark held cart as orphan (test addon removal) |
| `SaucedCartsDebug.clearOrphan()` | Clear orphan status from held cart |
| `SaucedCartsDebug.showSchema()` | Show detailed ModData for held cart |
| `SaucedCartsDebug.findOrphans()` | List all orphan carts in inventory |
| `SaucedCartsDebug.recoverOrphan()` | Manually recover items from held orphan |
| `SaucedCartsDebug.testOrphanNotification()` | Test the warning UI |
| `SaucedCartsDebug.testMigrationSystem()` | Run comprehensive tests |

### Test Scenarios

**Scenario 1: Schema Upgrade**
```lua
-- 1. Equip a cart
SaucedCartsDebug.giveCart("ShoppingCart")

-- 2. Check current schema
SaucedCartsDebug.showSchema()
-- Should show: schemaVersion = 1

-- 3. Bump SCHEMA_VERSION to 2 in Core.lua, reload game
-- 4. Check again
SaucedCartsDebug.showSchema()
-- Should show: schemaVersion = 2, previousVersion = 1
```

**Scenario 2: Orphan Detection**
```lua
-- 1. Equip a cart with items inside
SaucedCartsDebug.giveCart("ShoppingCart")
-- Add items to cart...

-- 2. Mark as orphan (simulates addon removal)
SaucedCartsDebug.makeOrphan()

-- 3. Drop the cart
-- Right-click -> Drop

-- 4. Right-click cart in inventory
-- Should show "Recover X items from broken cart" option
```

**Scenario 3: Orphan Recovery**
```lua
-- 1. Create orphan cart
SaucedCartsDebug.giveCart("ShoppingCart")
SaucedCartsDebug.makeOrphan()

-- 2. Manual recovery
SaucedCartsDebug.recoverOrphan()
-- Items transferred, cart deleted

-- 3. Or use context menu
-- Right-click cart -> "Recover X items"
```

## MP Considerations

### What Syncs

| Operation | Sync Method |
|-----------|-------------|
| Item recovery | `sendAddItemToContainer()` |
| Cart removal | `sendRemoveItemFromContainer()` |
| ModData changes | Automatic (ModData syncs) |

### Context Sensitivity

- Migration runs on `OnGameStart` for each player
- Orphan notification is client-only (UI)
- Recovery actions sync inventory changes to server

### Edge Cases

1. **Cart on ground when addon removed**: Orphan detection runs on pickup
2. **MP save with orphan**: Each client detects orphans independently
3. **Addon re-added**: `restoredAt` timestamp set, orphan flag cleared

## Future Migration Example

When releasing v2.0 with a renamed cart type:

```lua
-- Core.lua changes:

-- 1. Bump version
SaucedCarts.SCHEMA_VERSION = 2

-- 2. Add type alias
SaucedCarts.TYPE_ALIASES = {
    ["SaucedCarts.ShoppingCart"] = "SaucedCarts.GroceryCart",
}

-- 3. Update CartData.lua with new type name
-- 4. Update item script with new type name
```

Players loading old saves will:
1. See cart migrated to new type
2. ModData records original type for debugging
3. No player action required

## Troubleshooting

### Cart not detected as orphan

Check that the cart has SaucedCarts markers:
```lua
SaucedCartsDebug.showSchema()
-- Look for: multipliersApplied, schemaVersion, or fillState
```

### Recovery option not appearing

Verify orphan status:
```lua
-- Check ModData
SaucedCartsDebug.showSchema()
-- Should show: isOrphan = true

-- Check cache
print(SaucedCarts._orphanedCarts[cart:getID()])
```

### Items not transferring in MP

Ensure sync functions are called:
```lua
sendAddItemToContainer(playerInv, item)
sendRemoveItemFromContainer(playerInv, cart)
```

## File Reference

| File | Context | Purpose |
|------|---------|---------|
| `Core.lua` | shared | SCHEMA_VERSION, TYPE_ALIASES, calls migration |
| `Migration.lua` | shared | Migration logic, orphan detection |
| `OrphanRecovery.lua` | client | UI notifications, context menu |
| `DebugCommands.lua` | client | Testing commands |
