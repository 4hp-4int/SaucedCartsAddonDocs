================================================================================
SaucedCarts Addon Template
================================================================================

This is a complete template for creating a SaucedCarts addon mod.

================================================================================
QUICK START
================================================================================

1. Copy this entire ADDON_TEMPLATE folder to your Workshop folder:
   C:\Users\[YourName]\Zomboid\Workshop\YourModName\

2. Find and replace "MyCartAddon" with your mod name in ALL files:
   - common/mod.info          (id and name fields)
   - 42/media/scripts/*.txt   (module name, rename files too)
   - 42/media/lua/shared/     (folder name)
   - init.lua                 (all references)

3. Find and replace "MyCart" with your cart name:
   - items_*.txt (item name)
   - models_*.txt (model name)
   - init.lua (fullType and registration)

4. Replace placeholder files with your assets:
   - 42/media/models_X/weapons/2handed/mycart.fbx    (3D model)
   - 42/media/textures/weapons/2handed/mycart.png    (model texture)
   - 42/media/textures/Item_MyCart.png               (inventory icon)

5. Test in-game:
   - Enable both SaucedCarts and your addon
   - Run: SaucedCartsDebug.listRegistered()
   - Your cart should appear in the list!

================================================================================
FILE STRUCTURE (Workshop-style for Build 42)
================================================================================

YourModName/
├── README.txt                                    <- Delete when done
├── common/
│   └── mod.info                                  <- Mod metadata
└── 42/
    └── media/
        ├── lua/shared/MyCartAddon/
        │   └── init.lua                          <- Registration code
        ├── scripts/
        │   ├── items_mycartaddon.txt             <- Item definitions
        │   └── models_mycartaddon.txt            <- Model mappings
        ├── models_X/weapons/2handed/
        │   └── mycart.fbx                        <- Your 3D model
        └── textures/
            ├── Item_MyCart.png                   <- Inventory icon (32x32)
            └── weapons/2handed/
                └── mycart.png                    <- Model texture

================================================================================
CRITICAL: NAMING MUST MATCH
================================================================================

These names must ALL match (case-sensitive):

  mod.info:           id=MyCartAddon
  items_*.txt:        module MyCartAddon { item MyCart ... }
  init.lua:           fullType = "MyCartAddon.MyCart"

  items_*.txt:        StaticModel = MyCart,
  models_*.txt:       model MyCart { ... }

  items_*.txt:        Icon = MyCart,
  textures:           Item_MyCart.png

================================================================================
TESTING YOUR ADDON
================================================================================

Debug commands (Lua console, debug mode):

  SaucedCartsDebug.listRegistered()
    Lists all registered cart types - your cart should appear

  SaucedCartsDebug.checkRegistration("MyCartAddon.MyCart")
    Shows detailed info about your cart registration

  SaucedCartsDebug.spawnCart("MyCart")
    Spawns your cart at player position

  SaucedCartsDebug.giveCart("MyCart")
    Gives cart directly to player hands

  SaucedCartsTweaker.enable()
    Real-time model positioning tool (adjust offset/rotate/scale)

================================================================================
COMMON MISTAKES
================================================================================

1. ITEM NOT IN DEBUG LIST
   - Check module name in items_*.txt matches mod id
   - Check item script has no syntax errors
   - Try: instanceItem("MyCartAddon.MyCart") in console

2. CART SPAWNS BUT INVISIBLE
   - Model name must match between items_*.txt and models_*.txt
   - Check mesh path is correct (folder/file|objectname)
   - Verify FBX file exists at specified path

3. CART HAS NO TEXTURE
   - Check texture path in models_*.txt (no file extension)
   - Verify PNG file exists at textures/weapons/2handed/

4. REGISTRATION FAILS
   - Check fullType format: "ModuleId.ItemName"
   - Check SaucedCarts is enabled before your addon

================================================================================
NEED HELP?
================================================================================

- See ADDON_GUIDE.md for detailed documentation
- Check the SaucedCarts workshop page for updates

================================================================================
