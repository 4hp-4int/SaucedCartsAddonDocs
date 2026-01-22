-- ============================================================================
-- MyCartAddon/init.lua
-- ============================================================================
-- PURPOSE: Registers custom cart types with SaucedCarts.
--          This file runs on both client and server.
--
-- CONTEXT: SHARED
--
-- HOW IT WORKS:
--   1. SaucedCarts loads first (because of require= in mod.info)
--   2. This file runs and calls SaucedCarts.registerCart()
--   3. SaucedCarts adds your cart to its registry
--   4. Your cart automatically works with pickup, drop, context menus, etc.
--   5. If you specified spawnRooms, your cart spawns in the world
-- ============================================================================

-- ============================================================================
-- REGISTRATION
-- ============================================================================
-- Register your cart types here. Only 'name' is required - everything else
-- has sensible defaults.

-- Helper function to safely register (handles case where SaucedCarts isn't loaded)
local function registerCarts()
    -- Check if SaucedCarts is available
    if not SaucedCarts or not SaucedCarts.registerCart then
        -- Queue for later if SaucedCarts loads after us (shouldn't happen with require=)
        print("[MyCartAddon] WARNING: SaucedCarts not loaded yet, queueing registration")
        SaucedCarts = SaucedCarts or {}
        SaucedCarts._pendingRegistrations = SaucedCarts._pendingRegistrations or {}
        table.insert(SaucedCarts._pendingRegistrations, {
            fullType = "MyCartAddon.MyCart",
            data = {
                name = "My Custom Cart",
                description = "A custom cart added by MyCartAddon.",
                capacity = 50,
                weightReduction = 90,
                runSpeedModifier = 0.75,
                conditionMax = 100,
                baseWeight = 5.0,
                repairItem = "Base.ScrapMetal",
                repairAmount = 10,
                spawnRooms = {},  -- Empty = no world spawns (spawn manually or via recipe)
                spawnWeight = 1,
            }
        })
        return
    end

    -- ========================================================================
    -- REGISTER: MyCart
    -- ========================================================================
    -- IMPORTANT: The fullType MUST match your module.itemname exactly!
    -- Module = MyCartAddon (from mod.info id)
    -- Item = MyCart (from items_mycartaddon.txt)
    -- Therefore fullType = "MyCartAddon.MyCart"

    local success, err = SaucedCarts.registerCart("MyCartAddon.MyCart", {
        -- REQUIRED: Display name shown in UI
        name = "My Custom Cart",

        -- OPTIONAL: Flavor text (shows in tooltips)
        description = "A custom cart added by MyCartAddon.",

        -- OPTIONAL: Storage capacity (default: 50)
        -- This should match your items_*.txt Capacity value
        capacity = 50,

        -- OPTIONAL: Weight reduction percentage (default: 90)
        -- 90 means items inside weigh only 10% of normal
        weightReduction = 90,

        -- OPTIONAL: Movement speed multiplier (default: 0.75)
        -- 0.75 means player moves at 75% speed while holding cart
        runSpeedModifier = 0.75,

        -- OPTIONAL: Maximum durability (default: 100)
        conditionMax = 100,

        -- OPTIONAL: Base weight in kg (default: 5.0)
        baseWeight = 5.0,

        -- OPTIONAL: Item used for repairs (default: "Base.ScrapMetal")
        repairItem = "Base.ScrapMetal",

        -- OPTIONAL: Condition restored per repair (default: 10)
        repairAmount = 10,

        -- OPTIONAL: Room-based world spawning (carts spawn on ground in matching rooms)
        -- Each entry specifies a room name and spawn chance (0-100%)
        -- Leave empty for no world spawns (player must craft or find via other means)
        -- Common rooms: "warehouse", "garage", "farmstorage", "gigamart", "grocery"
        spawnRooms = {
            -- Uncomment and modify these to add world spawns:
            -- { room = "warehouse", chance = 30 },
            -- { room = "garage", chance = 20 },
        },

        -- OPTIONAL: Relative spawn weight (default: 1)
        -- Higher = more common. 2-3 is typical for common items.
        spawnWeight = 1,
    })

    if success then
        print("[MyCartAddon] Successfully registered MyCart")
    else
        print("[MyCartAddon] ERROR: Failed to register MyCart: " .. tostring(err))
    end

    -- ========================================================================
    -- ADD MORE CARTS HERE
    -- ========================================================================
    -- Copy the registerCart block above for each additional cart type.
    -- Remember to also add item definitions in items_mycartaddon.txt and
    -- model definitions in models_mycartaddon.txt for each cart.
end

-- Run registration
registerCarts()

print("[MyCartAddon] Loaded")
