-- ============================================================================
-- MyCartAddon/init.lua
-- ============================================================================
-- PURPOSE: Registers custom cart types with SaucedCarts.
--          This file runs on both client and server.
-- ============================================================================

local function registerCarts()
    -- Check if SaucedCarts is available
    if not SaucedCarts or not SaucedCarts.registerCart then
        -- Queue for later (fallback if load order is wrong)
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
                spawnRooms = {},
                spawnWeight = 1,
            }
        })
        return
    end

    -- Register the cart
    -- IMPORTANT: fullType must match "ModuleId.ItemName" from items_*.txt
    local success, err = SaucedCarts.registerCart("MyCartAddon.MyCart", {
        name = "My Custom Cart",
        description = "A custom cart added by MyCartAddon.",
        capacity = 50,
        weightReduction = 90,
        runSpeedModifier = 0.75,
        conditionMax = 100,
        baseWeight = 5.0,
        repairItem = "Base.ScrapMetal",
        repairAmount = 10,
        spawnRooms = {
            -- Uncomment to enable world spawning:
            -- { room = "warehouse", chance = 30 },
            -- { room = "garage", chance = 20 },
        },
        spawnWeight = 1,
    })

    if success then
        print("[MyCartAddon] Successfully registered MyCart")
    else
        print("[MyCartAddon] ERROR: Failed to register MyCart: " .. tostring(err))
    end
end

registerCarts()
print("[MyCartAddon] Loaded")
