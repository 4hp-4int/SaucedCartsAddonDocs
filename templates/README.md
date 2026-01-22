# AnimSet XML Templates

Ready-to-use templates for creating custom cart animations.

## Quick Start

1. Copy the template files you need
2. Find & replace `__PLACEHOLDER_TYPE__` with your type name (e.g., `Cart`, `Wheelbarrow`)
3. Find & replace `__PLACEHOLDER_WEAPON_VALUE__` with your trigger value (e.g., `cart`)
4. Place in the correct folder under `media/AnimSets/player/`

## Template Files

### Body Animations (Full Body)

| Template | Destination Folder | Purpose |
|----------|-------------------|---------|
| `body_idle_template.xml` | `player/idle/` | Standing still |
| `body_walk_template.xml` | `player/movement/` | Walking |
| `body_run_template.xml` | `player/run/` | Jogging |
| `body_sprint_template.xml` | `player/sprint/` | Sprinting |

### Masking Animations (Hand Overlay)

| Template | Destination Folder | Purpose |
|----------|-------------------|---------|
| `masking_idle_template.xml` | `player/maskingright/` | Idle hand position |
| `masking_walk_template.xml` | `player/maskingright/` | Walk hand position |
| `masking_run_template.xml` | `player/maskingright/` | Run hand position |
| `masking_sprint_template.xml` | `player/maskingright/` | Sprint hand position |

## Placeholder Reference

| Placeholder | Replace With | Example |
|-------------|--------------|---------|
| `__PLACEHOLDER_TYPE__` | Your cart type name | `Cart` |
| `__PLACEHOLDER_WEAPON_VALUE__` | Weapon variable trigger | `cart` |

## Example: Creating "Wheelbarrow" AnimSets

### Step 1: Copy and rename body templates

```
body_idle_template.xml    → idle_wheelbarrow.xml     (to player/idle/)
body_walk_template.xml    → walk_wheelbarrow.xml     (to player/movement/)
body_run_template.xml     → run_wheelbarrow.xml      (to player/run/)
body_sprint_template.xml  → sprint_wheelbarrow.xml   (to player/sprint/)
```

### Step 2: Find & replace in each file

```
__PLACEHOLDER_TYPE__         → Wheelbarrow
__PLACEHOLDER_WEAPON_VALUE__ → wheelbarrow
```

### Step 3: Copy and rename masking templates

```
masking_idle_template.xml   → holdingwheelbarrowright.xml    (to player/maskingright/)
masking_walk_template.xml   → walkwheelbarrowright.xml       (to player/maskingright/)
masking_run_template.xml    → runwheelbarrowright.xml        (to player/maskingright/)
masking_sprint_template.xml → _sprintwheelbarrowright.xml    (to player/maskingright/)
```

### Step 4: Update Lua to trigger

```lua
player:setVariable("Weapon", "wheelbarrow")
player:setVariable("RightHandMask", "holdingwheelbarrowright")
player:setVariable("LeftHandMask", "holdingwheelbarrowleft")
```

## Naming Conventions

### .X Animation Files
```
_Bob_Idle<Type>.X
_Bob_Walk<Type>.X
_Bob_Run<Type>.X
_Bob_Sprint_<Type>.X
```

### AnimationSet Names (inside .X files)
```
AnimationSet Bob_Idle<Type>
AnimationSet Bob_Walk<Type>
AnimationSet Bob_Run<Type>
AnimationSet Bob_Sprint_<Type>
```

### AnimSet XML Files
```
idle_<type>.xml          (player/idle/)
walk_<type>.xml          (player/movement/)
run_<type>.xml           (player/run/)
sprint_<type>.xml        (player/sprint/)
holding<type>right.xml   (player/maskingright/)
walk<type>right.xml      (player/maskingright/)
run<type>right.xml       (player/maskingright/)
_sprint<type>right.xml   (player/maskingright/)
```

### State Names (m_Name in XML)
```
Idle<Type>
walk<Type>
run<Type>
sprint<Type>
holding<type>right
walk<type>right
run<type>right
sprint<type>right
```

## See Also

- `../ANIMSET_GUIDE.md` - Full documentation on how AnimSets work
- `../ASSET_REQUIREMENTS.md` - 3D model and animation requirements
