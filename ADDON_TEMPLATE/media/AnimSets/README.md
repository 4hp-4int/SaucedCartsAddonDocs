# AnimSets Setup for Custom Carts

This folder contains template AnimSet XML files for creating custom cart animations.

## Quick Start

1. **Copy vanilla parent files** - The `x_extends` attribute requires parent files to exist locally:
   ```
   From: [PZ Install]/media/AnimSets/player/
   To:   YourMod/media/AnimSets/player/

   Required files:
   - movement/defaultWalk.xml
   - run/defaultRun.xml
   - sprint/defaultSprint.xml
   - idle/Idle.xml
   ```

2. **Rename template files** - Replace "yourcart" with your cart type name:
   ```
   walk_yourcart.xml  -> walk_wheelbarrow.xml
   run_yourcart.xml   -> run_wheelbarrow.xml
   sprint_yourcart.xml -> sprint_wheelbarrow.xml
   idle_yourcart.xml  -> idle_wheelbarrow.xml
   ```

3. **Update file contents** - Find/replace in each file:
   - `YourCart` -> `Wheelbarrow` (in node names)
   - `yourcart` -> `wheelbarrow` (in Weapon condition value)
   - `Bob_YourCart_Walk` -> Your actual animation name

4. **Set Weapon variable in Lua** - In your equip handler:
   ```lua
   player:setVariable("Weapon", "wheelbarrow")
   ```

## Critical Requirements

**2D Blend Nodes MUST have ALL properties:**
```xml
<m_2DBlends referenceID="1">
    <m_AnimName>YourAnimation</m_AnimName>
    <m_XPos>0.00</m_XPos>      <!-- REQUIRED -->
    <m_YPos>0.00</m_YPos>      <!-- REQUIRED -->
    <m_SpeedScale>0.80</m_SpeedScale>  <!-- REQUIRED -->
</m_2DBlends>
```

Missing ANY property will cause movement speed to be stuck at ~0.06.

## Blend Node Counts

Match your parent file's blend node count:
- `Idle.xml` - 3 blend nodes
- `defaultWalk.xml` - 6 blend nodes
- `defaultRun.xml` - 8 blend nodes
- `defaultSprint.xml` - 5 blend nodes

## Transition Names

Transition targets must match your node names exactly (case-sensitive):
- `IdleYourCart` (from idle_yourcart.xml)
- `walkYourCart` (from walk_yourcart.xml)
- `runYourCart` (from run_yourcart.xml)
- `sprintYourCart` (from sprint_yourcart.xml)

## Troubleshooting

**Slow movement / MoveSpeed stuck at 0.06:**
- Check that ALL `m_2DBlends` have `m_XPos`, `m_YPos`, `m_SpeedScale`
- Verify `referenceID` values are sequential (1, 2, 3...)
- Ensure correct number of blend nodes for parent

**Animation not playing:**
- Verify Weapon variable is set correctly in Lua
- Check `m_Value` in `m_Conditions` matches exactly
- Ensure parent XML files exist in your mod

**Jerky transitions:**
- Adjust `m_blendInTime` values (0.1-0.5 typical)

See `docs/ANIMSET_GUIDE.md` for comprehensive documentation.
