# StarlitLibrary Compatibility Report

**StarlitLibrary Version Analyzed**: 1.5.2 (December 2025)
**SaucedCarts Version**: 1.0.0
**Workshop ID**: [3378285185](https://steamcommunity.com/sharedfiles/filedetails/?id=3378285185)
**Documentation**: https://demiurgequantified.github.io/StarlitLibrary/

## Executive Summary

**No conflicts detected.** SaucedCarts and StarlitLibrary operate in completely separate areas. StarlitLibrary provides a **free enhancement** - it automatically renders container contents icons in tooltips, which benefits carts without any code changes.

---

## Systems Analysis

### StarlitLibrary Hooks

| System | What It Hooks | Impact on SaucedCarts |
|--------|---------------|----------------------|
| `ISInventoryPane.refreshContainer` | Fires `preRenderItems` event before rendering | None - calls original |
| `ISToolTipInv.render` | Fires `onFillItemTooltip` event for tooltips | None - enhancement opportunity |
| `itemMetatable.DoTooltip` | Runtime override during render | None - temporary, restored after |

### SaucedCarts Systems

| System | Implementation | Conflict Risk |
|--------|----------------|---------------|
| Context Menus | Vanilla `OnFillWorldObjectContextMenu` / `OnFillInventoryObjectContextMenu` | None - StarlitLibrary doesn't touch these |
| Pickup Action | Custom `ISCartPickupAction` (MP-safe pattern) | None |
| Drop Action | Vanilla `ISDropWorldItemAction` | None |
| Player State | `OnPlayerUpdate` for restrictions | None |
| Distributions | `OnPreDistributionMerge` | None |

---

## Free Enhancement: Container Tooltips

StarlitLibrary's InventoryUI module has special handling for `InventoryContainer` items. When installed, cart tooltips automatically show icons of their contents with no code changes needed from SaucedCarts.

---

## Optional Enhancement: Rich Tooltips

To add condition bars, weight stats, or fill percentage to cart tooltips, use StarlitLibrary's `onFillItemTooltip` event with a soft dependency:

### Soft Dependency Pattern

```lua
-- In a new Tooltips.lua (client)
local function addCartTooltipInfo(tooltip, layout, item)
    if not SaucedCarts.isCart(item) then return end

    local InventoryUI = require("Starlit/client/ui/InventoryUI")

    -- Add condition bar
    local condition = item:getCondition() / item:getConditionMax()
    InventoryUI.addTooltipBar(layout, getText("UI_SaucedCarts_Condition"), condition)

    -- Add weight info
    local container = item:getItemContainer()
    local usedWeight = container:getCapacityWeight()
    local maxCapacity = container:getCapacity()
    InventoryUI.addTooltipKeyValue(layout, "Weight",
        string.format("%.1f / %d", usedWeight, maxCapacity))
end

-- Only register if StarlitLibrary is present
local success, InventoryUI = pcall(require, "Starlit/client/ui/InventoryUI")
if success and InventoryUI and InventoryUI.onFillItemTooltip then
    InventoryUI.onFillItemTooltip:addListener(addCartTooltipInfo)
    SaucedCarts.log("Tooltips: StarlitLibrary mode")
else
    SaucedCarts.log("Tooltips: standalone mode")
end
```

### Event Callback Signature

```lua
function callback(tooltip, layout, item)
    -- tooltip: The tooltip object
    -- layout: ObjectTooltip.Layout for adding content
    -- item: The InventoryItem being displayed
end
```

### Available Tooltip Functions

From StarlitLibrary's InventoryUI module:

| Function | Purpose |
|----------|---------|
| `addTooltipBar(layout, label, value)` | Add progress bar (0-1 range) |
| `addTooltipKeyValue(layout, key, value)` | Add key/value pair |
| `addTooltipLabel(layout, text)` | Add text label |
| `addTooltipInteger(layout, label, value)` | Add integer with auto-coloring |
| `removeTooltipElement(layout, element)` | Remove existing element |
| `getTooltipElementByLabel(layout, label)` | Find element by label |

### Detection Methods

```lua
-- Method 1: pcall require (recommended)
local success, InventoryUI = pcall(require, "Starlit/client/ui/InventoryUI")

-- Method 2: Check activated mods
if getActivatedMods():contains("StarlitLibrary") then
```

---

## Compatibility Matrix

| User Setup | Cart Tooltip | Notes |
|------------|--------------|-------|
| SaucedCarts only | Vanilla tooltip | Basic item info |
| SaucedCarts + StarlitLibrary | Container icons shown | Free enhancement |
| SaucedCarts + Tooltips.lua + StarlitLibrary | Full cart stats | Condition, weight, fill % |

---

## Recommendations

### Safe Defaults
- **No hard dependency** - Always use `pcall` when requiring StarlitLibrary modules
- **Graceful fallback** - Work without StarlitLibrary installed

### Avoid
- Copying StarlitLibrary files into mod (against their license)
- Hooking `ISToolTipInv.render` directly when StarlitLibrary handles it

---

## Conclusion

**SaucedCarts is fully compatible with StarlitLibrary v1.5.2.** No code changes required. Users with StarlitLibrary installed automatically get enhanced container tooltips showing cart contents.
