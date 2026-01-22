# Cart Visual State Testing Guide

Quick reference for testing the fill-state visual system.

## Fill State Thresholds

| Fill % | State | Model Name |
|--------|-------|------------|
| 0-32% | empty | `ShoppingCartModel` |
| 33-65% | partial | `ShoppingCartPartialModel` |
| 66%+ | full | `ShoppingCartFullModel` |

## Model Assets

| Model | Mesh File | Texture |
|-------|-----------|---------|
| Empty | `ShoppingCart_PZ\|ShoppingCart` | `ShoppingCart_Atlas` |
| Partial | `ShoppingCartHalfFull_PZ\|ShoppingCart` | `ShoppingCart_Atlas` |
| Full | `ShoppingCartFull_PZ\|ShoppingCart` | `ShoppingCart_Atlas` |

## Debug Commands

Run in Lua console (debug mode or admin):

```lua
-- Spawn a cart on the ground
SaucedCartsDebug.spawnCart("ShoppingCart")

-- Give cart directly to player (equipped)
SaucedCartsDebug.giveCart("ShoppingCart")

-- Force set fill state (bypasses weight calculation)
SaucedCartsDebug.setFillState("empty")
SaucedCartsDebug.setFillState("partial")
SaucedCartsDebug.setFillState("full")

-- Cycle through states: empty -> partial -> full -> empty
SaucedCartsDebug.cycleFillState()

-- Show current visual status
SaucedCartsDebug.showVisualStatus()
```

## Test Scenarios

### 1. Manual Fill State Override
```lua
SaucedCartsDebug.giveCart("ShoppingCart")
SaucedCartsDebug.setFillState("empty")    -- Verify empty model
SaucedCartsDebug.setFillState("partial")  -- Verify partial model
SaucedCartsDebug.setFillState("full")     -- Verify full model
```

### 2. Drop Updates Visual
1. `SaucedCartsDebug.giveCart("ShoppingCart")`
2. Open cart inventory, add items to ~50% capacity
3. Right-click → Drop
4. **Expected**: Cart on ground shows partial model

### 3. Aim-to-Drop Updates Visual
1. `SaucedCartsDebug.giveCart("ShoppingCart")`
2. Fill cart to ~80% capacity
3. Right-click to aim (triggers instant drop)
4. **Expected**: Cart on ground shows full model

### 4. Ground Cart Transfer (Loot Panel)
1. `SaucedCartsDebug.spawnCart("ShoppingCart")` - spawns empty
2. Open loot panel, drag items INTO cart until ~50%
3. Close loot panel, look at cart
4. **Expected**: Cart shows partial model (updates after 3 ticks)

### 5. Threshold Boundaries
Test exact threshold values:

| Cart Capacity | Weight to Add | Expected State |
|---------------|---------------|----------------|
| 60 | 0-19 | empty |
| 60 | 20-38 | partial |
| 60 | 39+ | full |

*Note: Default ShoppingCart capacity is 60*

## Verification Checklist

- [ ] Empty model renders correctly (world + equipped)
- [ ] Partial model renders correctly (world + equipped)
- [ ] Full model renders correctly (world + equipped)
- [ ] Model updates on menu drop
- [ ] Model updates on aim-to-drop
- [ ] Model updates on ground transfer (3-tick delay)
- [ ] `showVisualStatus()` reports accurate state
- [ ] MP: Visual syncs to other clients

## Troubleshooting

### Model not changing
```lua
SaucedCartsDebug.showVisualStatus()
```
Check:
- `Fill State` matches expected
- `Expected Model` matches `Actual Static Model`
- If mismatch, model definition may be missing

### Wrong model displayed
1. Verify mesh files exist in `media/models_X/weapons/2handed/`
2. Verify texture exists in `media/textures/weapons/2handed/`
3. Check console for model loading errors

### Transfer not triggering update
- Ensure cart is ON GROUND (has world item)
- Check debug log for "Queued cart visual update"
- Wait 3 ticks (~100ms) for deferred processing

## File Locations

| File | Purpose |
|------|---------|
| `media/lua/shared/SaucedCarts/CartVisuals.lua` | Visual state logic |
| `media/lua/client/SaucedCarts/CartStateHandler.lua` | Triggers + transfer hook |
| `media/lua/client/SaucedCarts/DebugCommands.lua` | Test commands |
| `media/scripts/models_saucedcarts.txt` | Model definitions |

## Adjusting Thresholds

In `CartVisuals.lua`:
```lua
local FILL_PARTIAL_THRESHOLD = 0.33  -- Below = empty
local FILL_FULL_THRESHOLD = 0.66     -- Above = full, between = partial
```
