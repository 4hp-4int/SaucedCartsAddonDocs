================================================================================
SaucedCarts Addon Template
================================================================================

This is a complete template for creating a SaucedCarts addon mod.
Follow the steps below to create your own custom cart types.

================================================================================
QUICK START (5 minutes)
================================================================================

1. Copy this entire ADDON_TEMPLATE folder to your PZ mods directory:
   C:\Users\[YourName]\Zomboid\mods\

2. Rename the folder to your mod name (e.g., "MyAwesomeCarts")

3. Find and replace "MyCartAddon" with your mod name in ALL files:
   - mod.info (id field and name field)
   - items_mycartaddon.txt (rename file + module name inside)
   - models_mycartaddon.txt (rename file)
   - init.lua (folder name + all references)

4. Replace the placeholder assets with your actual 3D model and textures

5. Test in-game:
   - Enable both SaucedCarts and your addon in the mod list
   - Start a game with debug mode
   - Run: SaucedCartsDebug.listRegistered()
   - Your cart should appear in the list!

================================================================================
FILE STRUCTURE
================================================================================

ADDON_TEMPLATE/
├── mod.info                              <- Mod metadata (EDIT THIS)
├── README.txt                            <- This file (delete when done)
├── media/
│   ├── scripts/
│   │   ├── items_mycartaddon.txt         <- Item definitions (EDIT THIS)
│   │   └── models_mycartaddon.txt        <- Model mappings (EDIT THIS)
│   ├── lua/shared/MyCartAddon/
│   │   └── init.lua                      <- Registration code (EDIT THIS)
│   ├── textures/
│   │   ├── PUT_INVENTORY_ICON_HERE.txt   <- Replace with Item_MyCart.png
│   │   └── weapons/2handed/
│   │       └── PUT_MODEL_TEXTURE_HERE.txt <- Replace with mycart.png
│   └── models_X/weapons/2handed/
│       └── PUT_FBX_MODEL_HERE.txt        <- Replace with mycart.fbx

================================================================================
ADDING MORE CART TYPES
================================================================================

For each additional cart type, you need to add:

1. Item definition in items_*.txt (copy the "item MyCart" block)
2. Model definition in models_*.txt (copy the "model MyCartModel" block)
3. Registration in init.lua (copy the registerCart() call)
4. New 3D model, texture, and inventory icon files

================================================================================
TESTING YOUR ADDON
================================================================================

Debug commands (in Lua console with debug mode):

  SaucedCartsDebug.listRegistered()
    - Lists all registered cart types (your cart should appear)

  SaucedCartsDebug.checkRegistration("MyCartAddon.MyCart")
    - Shows detailed info about your cart registration

  SaucedCartsDebug.spawnCart("MyCart")
    - Spawns your cart at player position (if item definition is correct)

  SaucedCartsDebug.giveCart("MyCart")
    - Gives cart directly to player hands

Common issues:
- Cart not in list: Check init.lua registration and mod load order
- Cart spawns but invisible: Check model paths in models_*.txt
- Cart has no texture: Check texture paths in models_*.txt
- "Unknown cart type": Check fullType matches module.itemname exactly

================================================================================
NEED HELP?
================================================================================

- See ADDON_GUIDE.md for detailed documentation
- See ASSET_REQUIREMENTS.md for 3D model and texture specifications
- Check the SaucedCarts workshop page for updates

================================================================================
