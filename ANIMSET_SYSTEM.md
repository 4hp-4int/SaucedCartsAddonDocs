# Project Zomboid AnimSet System - Complete Guide

This document covers everything learned about PZ's AnimSet system through debugging SaucedCarts custom animations.

**Related Documentation:**
- `ANIMATION_XML_REFERENCE.md` - **Technical deep-dive** with decompiled Java source evidence for all XML elements
- `ANIMSET_GUIDE.md` - Step-by-step tutorial for creating AnimSets

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Animation vs Movement](#animation-vs-movement)
3. [AnimSet XML Structure](#animset-xml-structure)
4. [The x_extends Inheritance System](#the-x_extends-inheritance-system)
5. [Weapon Variable and Animation Selection](#weapon-variable-and-animation-selection)
6. [Blend Space System](#blend-space-system)
7. [Common Pitfalls](#common-pitfalls)
8. [File Naming Conventions](#file-naming-conventions)
9. [Creating Custom Weapon Animations](#creating-custom-weapon-animations)

---

## Core Concepts

### Animation System Overview

PZ's animation system consists of:

1. **AnimSets** - XML files defining animation states, conditions, transitions, and blend spaces
2. **FBX Files** - The actual animation data (located in `media/anims_X/`)
3. **Animation Variables** - Runtime values that control which animations play
4. **State Machine** - Manages transitions between animation states

### Key Directories

| Directory | Purpose |
|-----------|---------|
| `media/AnimSets/player/idle/` | Idle stance animations |
| `media/AnimSets/player/movement/` | Walk animations |
| `media/AnimSets/player/run/` | Run animations |
| `media/AnimSets/player/sprint/` | Sprint animations |
| `media/AnimSets/player/maskingright/` | Right arm masking layers |
| `media/AnimSets/player/maskingleft/` | Left arm masking layers |
| `media/anims_X/Bob/` | FBX animation files (prefix with `_`) |

---

## Animation vs Movement

**CRITICAL CONCEPT**: In PZ, animation and movement are **completely separate systems**.

### Animation System
- Purely visual - controls what the player model looks like
- Driven by animation variables (`Weapon`, `isMoving`, `WalkSpeed`, etc.)
- Configured via AnimSet XML files

### Movement System
- Controls actual player position in the world
- Driven by keyboard/gamepad input
- Handled by Java code in `IsoPlayer.java`
- Uses `playerMoveDir` and `currentSpeed` to calculate position changes

### Why This Matters

When your walk animation plays but the character doesn't move:
- The **animation system** is working (visual feedback)
- The **movement system** is blocked (no position change)

These are independent! A playing animation does NOT cause movement.

---

## AnimSet XML Structure

### Basic Structure

```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode>
    <m_Name>walkCart</m_Name>           <!-- State name (referenced by transitions) -->
    <m_AnimName>Bob_Cart_Walk</m_AnimName>  <!-- Default animation file -->
    <m_BlendTime>0.20</m_BlendTime>     <!-- Transition blend duration -->
    <m_SpeedScale>1.04</m_SpeedScale>   <!-- Animation playback speed -->

    <!-- Blend space scalars -->
    <m_Scalar>WalkInjury</m_Scalar>     <!-- X-axis variable -->
    <m_Scalar2>WalkSpeed</m_Scalar2>    <!-- Y-axis variable -->

    <!-- Conditions for when this state activates -->
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_Value>cart</m_Value>
    </m_Conditions>

    <!-- Blend space points -->
    <m_2DBlends referenceID="1">
        <m_AnimName>Bob_Cart_Walk</m_AnimName>
        <m_XPos>0.00</m_XPos>
        <m_YPos>1.00</m_YPos>
        <m_SpeedScale>0.80</m_SpeedScale>
    </m_2DBlends>

    <!-- Blend triangles (connect blend points) -->
    <m_2DBlendTri>
        <node1>1</node1>
        <node2>2</node2>
        <node3>3</node3>
    </m_2DBlendTri>

    <!-- State transitions -->
    <m_Transitions>
        <m_Target>IdleCart</m_Target>
        <m_blendInTime>0.3</m_blendInTime>
    </m_Transitions>

    <!-- Animation events (footsteps, sounds) -->
    <m_Events>
        <m_EventName>Footstep</m_EventName>
        <m_TimePc>0.2</m_TimePc>
        <m_ParameterValue>walk</m_ParameterValue>
    </m_Events>
</animNode>
```

### Key Fields

| Field | Purpose |
|-------|---------|
| `m_Name` | Unique state name, referenced by transitions |
| `m_AnimName` | FBX animation name (without `_` prefix or `.fbx` extension) |
| `m_Priority` | State priority (higher = preferred) |
| `m_ConditionPriority` | Condition matching priority |
| `m_Scalar` / `m_Scalar2` | Variables for 2D blend space (X/Y axes) |
| `m_Conditions` | When this state should activate |
| `m_2DBlends` | Points in the blend space |
| `m_2DBlendTri` | Triangles connecting blend points |
| `m_Transitions` | Valid transitions to other states |

---

## The x_extends Inheritance System

### Why Inheritance Matters

**This is the most important discovery**: Custom weapon AnimSets MUST extend vanilla base AnimSets for movement to work properly.

Without `x_extends`, your AnimSet is standalone and missing critical inherited behavior that the movement system depends on.

### How It Works

```xml
<animNode x_extends="defaultWalk.xml">
    <m_Name>walkCart</m_Name>
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
    <!-- Only override what you need to change -->
    <m_2DBlends>
        <m_AnimName>Bob_Cart_Walk</m_AnimName>
    </m_2DBlends>
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_Value>cart</m_Value>
    </m_Conditions>
</animNode>
```

### What Gets Inherited

When you use `x_extends`:
- Blend space configuration (m_Scalar, m_Scalar2)
- Blend point positions (m_XPos, m_YPos)
- Blend triangles (m_2DBlendTri)
- Events (footsteps)
- Base transitions

You only need to override:
- `m_Name` - Your unique state name
- `m_AnimName` - Your custom animation
- `m_2DBlends` - Just the animation names (positions inherited)
- `m_Conditions` - Your weapon type condition
- `m_Transitions` - Point to your other states

### Base Files to Extend

| Your State | Extend This |
|------------|-------------|
| Walk | `defaultWalk.xml` |
| Idle | `Idle.xml` |
| Run | `defaultRun.xml` |
| Sprint | `defaultSprint.xml` |

---

## Weapon Variable and Animation Selection

### Setting the Weapon Variable

For containers (non-weapons), set the `Weapon` variable via Lua:

```lua
-- In your state handler (client-side)
player:setVariable("Weapon", "cart")           -- Body animations
player:setVariable("RightHandMask", "holdingcartright")  -- Arm masking
player:setVariable("LeftHandMask", "holdingcartleft")
```

### Node Selection Algorithm (Critical)

**Source**: `AnimState.getAnimNodes()` in `AnimState.java`

The animation system selects which nodes to activate using this algorithm:

```java
// Nodes are PRE-SORTED by conditionPriority (descending), then condition count
AnimNode bestNode = null;
for (AnimNode node : sortedNodes) {
    // BREAK when we hit a node with LOWER priority than current best
    if (bestNode != null && bestNode.compareSelectionConditions(node) > 0) {
        break;  // Stop checking - we've found all matching high-priority nodes
    }
    if (node.checkConditions(varSource)) {
        bestNode = node;
        in_nodes.add(node);  // Add ALL matching nodes at same priority
    }
}
```

**`compareSelectionConditions()` sorting order** (from `AnimNode.java`):
1. Abstract nodes come last
2. Higher `conditionPriority` comes first
3. More conditions = higher priority (tiebreaker when conditionPriority is equal)

**Why this matters for custom animations:**
- If your cart node has `conditionPriority=10` and vanilla's `defaultRun` has `conditionPriority=0` (default)
- Your cart node is checked FIRST (sorted higher)
- When it matches (Weapon="cart"), the loop BREAKS before checking `defaultRun`
- Result: Only your animation plays, not the vanilla one with injury blends

### How Conditions Match

The animation system checks conditions to select the right AnimSet:

```xml
<m_Conditions>
    <m_Name>Weapon</m_Name>       <!-- Variable name to check -->
    <m_Type>STRING</m_Type>       <!-- Type: STRING, BOOL, GTR, LESS, etc. -->
    <m_Value>cart</m_Value>       <!-- Value to match -->
</m_Conditions>
```

### Vanilla Weapon Types

| Weapon Value | Used By |
|--------------|---------|
| `2handed` | Two-handed melee (sledgehammer, etc.) |
| `handgun` | Pistols |
| `firearm` | Rifles, shotguns |
| `spear` | Spears |
| `heavy` | Heavy items |
| `chainsaw` | Chainsaw |
| (empty) | Default/unarmed |

### Condition Format

**Use `m_Value`, not `m_StringValue`** for modern AnimSet format:

```xml
<!-- Correct -->
<m_Conditions>
    <m_Name>Weapon</m_Name>
    <m_Type>STRING</m_Type>
    <m_Value>cart</m_Value>
</m_Conditions>

<!-- Also works (older format) -->
<m_Conditions>
    <m_Name>Weapon</m_Name>
    <m_Type>STRING</m_Type>
    <m_StringValue>cart</m_StringValue>
</m_Conditions>
```

---

## Blend Space System

### How 2D Blend Spaces Work

The blend space interpolates between animations based on two variables:
- **X-axis**: `m_Scalar` (typically `WalkInjury` - injury level)
- **Y-axis**: `m_Scalar2` (typically `WalkSpeed` - movement speed)

### Blend Points

Each point in the blend space is defined by:

```xml
<m_2DBlends referenceID="1">
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
    <m_XPos>0.00</m_XPos>      <!-- X position (-1.0 to 1.0) -->
    <m_YPos>1.00</m_YPos>      <!-- Y position (0.0 to 1.0) -->
    <m_SpeedScale>0.80</m_SpeedScale>
</m_2DBlends>
```

### Vanilla Walk Blend Space Layout

```
Y (WalkSpeed)
1.0  [HeavyLimpL]---[LightLimpL]---[Normal]---[LightLimpR]---[HeavyLimpR]
     (-1.0)         (-0.5)         (0.0)      (0.5)          (1.0)

0.0  [Slow/Idle]
     (0.0)

     X (WalkInjury) →
```

### Blend Triangles

Triangles connect three blend points for interpolation:

```xml
<m_2DBlendTri>
    <node1>2</node1>   <!-- referenceID of first point -->
    <node2>4</node2>   <!-- referenceID of second point -->
    <node3>6</node3>   <!-- referenceID of third point -->
</m_2DBlendTri>
```

The system uses barycentric coordinates to blend between the three animations when the current (X, Y) falls within that triangle.

---

## File Loading Order (Critical)

**Source**: `ZomboidFileSystem.walkGameAndModFiles()` in `ZomboidFileSystem.java`

Understanding file loading order is critical for knowing what approaches work:

```java
public void walkGameAndModFiles(String relPath, boolean recursive, IWalkFilesVisitor consumer) {
    // 1. Walk VANILLA game files FIRST
    this.walkGameAndModFilesInternal(this.base.canonicalFile, relPath, recursive, consumer);

    // 2. Then walk each MOD's files (in mod load order)
    for (String modID : this.getModIDs()) {
        Mod mod = ChooseGameInfo.getAvailableModDetails(modID);
        this.walkGameAndModFilesInternal(mod.getCommonDir(), relPath, recursive, consumer);
        this.walkGameAndModFilesInternal(mod.getVersionDir(), relPath, recursive, consumer);
    }
}
```

And in `resolveAllFiles()`:
```java
if (!result.contains(relPath3)) {  // Skip duplicates by relative path
    result.add(relPath3);
}
```

**Key insight**: Vanilla files are loaded FIRST. Mod files with the **same relative path** are SKIPPED.

### What This Means

| Approach | Works? | Reason |
|----------|--------|--------|
| Add new AnimSet files (e.g., `run_cart.xml`) | ✅ Yes | New file, no vanilla equivalent |
| Override vanilla files (e.g., `defaultRun.xml`) | ❌ No | Vanilla loads first, mod copy ignored |
| Use `conditionPriority` to sort before vanilla | ✅ Yes | Node sorting happens after loading |
| Use STRNEQ in mod's copy of vanilla file | ❌ No | Mod's copy is never loaded |

### Correct Pattern for Custom Weapons

1. Create NEW AnimSet files (don't try to override vanilla)
2. Use `x_extends` to inherit from vanilla base
3. Set high `conditionPriority` (e.g., 10) so your node sorts before vanilla (priority 0)
4. Your condition (`Weapon="cart"`) matches first, loop breaks, vanilla never checked

```xml
<animNode x_extends="defaultRun.xml">
    <m_Name>runCart</m_Name>
    <m_Priority>10</m_Priority>
    <m_ConditionPriority>10</m_ConditionPriority>  <!-- CRITICAL: Sort before vanilla -->
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_Value>cart</m_Value>
    </m_Conditions>
</animNode>
```

---

## Common Pitfalls

### 1. Using m_deferredBoneAxis for Player Locomotion

**WRONG**: Adding `<m_deferredBoneAxis>Y</m_deferredBoneAxis>`

This tells PZ to extract movement from the animation's root bone. But:
- Vanilla player animations don't use this
- Your FBX animations are likely "in-place" (no root motion)
- Result: Animation plays but character doesn't move

**Solution**: Remove `m_deferredBoneAxis` from player locomotion AnimSets.

### 2. Not Using x_extends

**WRONG**: Creating standalone AnimSets without inheritance

```xml
<animNode>
    <m_Name>walkCart</m_Name>
    <!-- Full configuration from scratch -->
</animNode>
```

**Solution**: Extend the vanilla base:

```xml
<animNode x_extends="defaultWalk.xml">
    <m_Name>walkCart</m_Name>
    <!-- Only override what's needed -->
</animNode>
```

### 3. Not Setting conditionPriority

**WRONG**: Relying only on conditions to differentiate from vanilla nodes

```xml
<animNode x_extends="defaultRun.xml">
    <m_Name>runCart</m_Name>
    <!-- Missing m_ConditionPriority! Defaults to 0, same as vanilla -->
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_Value>cart</m_Value>
    </m_Conditions>
</animNode>
```

With `conditionPriority=0` (default), your node may be checked AFTER vanilla nodes that also pass their conditions (or have no conditions). This causes both nodes to activate simultaneously, blending vanilla's injury/limp animations with your custom animation.

**Solution**: Always set `m_ConditionPriority` higher than vanilla (which uses default 0):

```xml
<animNode x_extends="defaultRun.xml">
    <m_Name>runCart</m_Name>
    <m_Priority>10</m_Priority>
    <m_ConditionPriority>10</m_ConditionPriority>  <!-- Sort before vanilla -->
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_Value>cart</m_Value>
    </m_Conditions>
</animNode>
```

### 4. Trying to Override Vanilla AnimSet Files

**WRONG**: Placing modified vanilla files in your mod to add exclusion conditions

```
MyMod/media/AnimSets/player/run/defaultRun.xml  ← This is NEVER loaded!
```

PZ loads vanilla files first, then skips mod files with the same relative path.

**Solution**: Use `conditionPriority` in your custom nodes instead.

### 5. Mismatched State Names

Transitions reference states by `m_Name`. If names don't match exactly, transitions fail silently.

```xml
<!-- In idle_cart.xml -->
<m_Transitions>
    <m_Target>walkCart</m_Target>  <!-- Must match exactly -->
</m_Transitions>

<!-- In walk_cart.xml -->
<m_Name>walkCart</m_Name>  <!-- This is what gets matched -->
```

### 4. FBX File Naming

FBX files in `media/anims_X/Bob/` must be prefixed with underscore:
- `_Bob_Cart_Walk.fbx` ✓
- `Bob_Cart_Walk.fbx` ✗

But AnimSet references omit the underscore:
- `<m_AnimName>Bob_Cart_Walk</m_AnimName>` ✓

### 5. Missing Blend Space Points

If your blend space has no point at Y=1.0 (full speed), the walk animation won't play when moving at full speed.

---

## File Naming Conventions

### AnimSet Files

Vanilla pattern: `{state}{weapontype}.xml`
- `walk2handed.xml`
- `Idle2Handed.xml`
- `walkhandgun.xml`

Your pattern can vary, but be consistent:
- `walk_cart.xml`
- `idle_cart.xml`

### FBX Animation Files

Pattern: `_{Character}_{Action}.fbx`
- `_Bob_Cart_Walk.fbx`
- `_Bob_Cart_Idle.fbx`

### m_Name Values

Match your transition targets:
- `walkCart` → transitions reference `walkCart`
- `IdleCart` → transitions reference `IdleCart`

---

## Creating Custom Weapon Animations

### Step-by-Step Process

1. **Create FBX animations** in Blender/Maya
   - Export to `media/anims_X/Bob/`
   - Prefix with underscore: `_Bob_YourAnim.fbx`

2. **Create AnimSets that extend vanilla bases**:

```xml
<!-- media/AnimSets/player/movement/walk_yourweapon.xml -->
<?xml version="1.0" encoding="utf-8"?>
<animNode x_extends="defaultWalk.xml">
    <m_Name>walkYourWeapon</m_Name>
    <m_AnimName>Bob_YourAnim_Walk</m_AnimName>
    <m_2DBlends><m_AnimName>Bob_YourAnim_Walk</m_AnimName></m_2DBlends>
    <m_2DBlends><m_AnimName>Bob_YourAnim_Walk</m_AnimName></m_2DBlends>
    <m_2DBlends><m_AnimName>Bob_YourAnim_Walk</m_AnimName></m_2DBlends>
    <m_2DBlends><m_AnimName>Bob_YourAnim_Walk</m_AnimName></m_2DBlends>
    <m_2DBlends><m_AnimName>Bob_YourAnim_Walk</m_AnimName></m_2DBlends>
    <m_2DBlends><m_AnimName>Bob_YourAnim_Walk</m_AnimName></m_2DBlends>
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_Value>yourweapon</m_Value>
    </m_Conditions>
    <m_Transitions><m_Target>IdleYourWeapon</m_Target></m_Transitions>
    <m_Transitions><m_Target>runYourWeapon</m_Target></m_Transitions>
    <m_Transitions><m_Target>sprintYourWeapon</m_Target></m_Transitions>
</animNode>
```

3. **Set animation variable in Lua**:

```lua
player:setVariable("Weapon", "yourweapon")
```

4. **Ensure all states exist** (idle, walk, run, sprint)

5. **Test in Animation Viewer** first, then in-game

### Minimum Required AnimSets

For a custom weapon type, you need at minimum:
- Idle (`idle/`)
- Walk (`movement/`)
- Run (`run/`)
- Sprint (`sprint/`)

Optional but recommended:
- Masking layers (`maskingright/`, `maskingleft/`)

---

## Debugging Tips

### Animation Plays But No Movement

1. Check for `m_deferredBoneAxis` - remove it
2. Verify AnimSet extends vanilla base
3. Test with vanilla weapon type (`2handed`) to isolate issue

### Animation Doesn't Play

1. Check condition matching (Weapon variable value)
2. Verify FBX file exists with correct name
3. Check m_Name matches transition targets
4. Look for errors in console

### Lua Debug Commands

```lua
-- Check current animation variables
print(getPlayer():getVariableString("Weapon"))
print(getPlayer():isPlayerMoving())
print(getPlayer():isBlockMovement())
```

### Restart Required

AnimSet changes require game restart to take effect (files are cached on load).

---

## Summary

The key insights for custom animations:

1. **Always use `x_extends`** to inherit from vanilla base AnimSets
2. **Always set `m_ConditionPriority`** higher than vanilla (e.g., 10) to ensure your node is checked first
3. **Never try to override vanilla AnimSet files** - they load first and mod copies are ignored
4. **Never use `m_deferredBoneAxis`** for player locomotion
5. **Animation ≠ Movement** - they're separate systems
6. **Match state names exactly** between m_Name and m_Target
7. **Prefix FBX files with underscore** but reference without it
8. **Set Weapon variable via Lua** for non-weapon items

### Required Pattern for Custom Weapon AnimSets

```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode x_extends="defaultRun.xml">
    <m_Name>runYourWeapon</m_Name>
    <m_AnimName>Bob_YourWeapon_Run</m_AnimName>
    <m_Priority>10</m_Priority>
    <m_ConditionPriority>10</m_ConditionPriority>  <!-- CRITICAL -->
    <m_SpeedScale>1.0</m_SpeedScale>
    <!-- Override blend points with your animation -->
    <m_2DBlends referenceID="1"><m_AnimName>Bob_YourWeapon_Run</m_AnimName></m_2DBlends>
    <!-- ... more blend points ... -->
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_Value>yourweapon</m_Value>
    </m_Conditions>
    <m_Transitions><m_Target>IdleYourWeapon</m_Target></m_Transitions>
    <!-- ... more transitions ... -->
</animNode>
```