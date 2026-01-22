# AnimSet Development Guide

This guide explains how Project Zomboid's animation system works and how to create custom AnimSets for SaucedCarts.

> **Verified Against**: Project Zomboid Build 42.13.1 vanilla AnimSet files.
> All claims backed by evidence from `media/AnimSets/player/` and `media/lua/` in the game installation.

**Related Documentation:**
- `ANIMATION_XML_REFERENCE.md` - **Technical deep-dive** with decompiled Java source evidence for all XML elements
- `ANIMSET_SYSTEM.md` - System overview and `x_extends` inheritance

## Table of Contents

1. [Overview](#overview)
2. [The Animation Chain](#the-animation-chain)
3. [File Structure](#file-structure)
4. [AnimSet XML Reference](#animset-xml-reference)
5. [State Machine Design](#state-machine-design)
6. [Body Animations vs Masking](#body-animations-vs-masking)
7. [Creating New AnimSets](#creating-new-animsets)
8. [Wiring to Lua](#wiring-to-lua)
9. [Testing & Debugging](#testing--debugging)
10. [Checklist](#checklist)
11. [Source Evidence](#source-evidence)

---

## Overview

PZ's animation system is a **state machine** where:
- **States** are animation nodes (idle, walk, run, sprint)
- **Conditions** determine which state is active (based on variables)
- **Transitions** define how states blend into each other
- **Masking** allows partial body animations to layer on top

For carts, we need:
- **Body animations**: Full body poses for idle/walk/run/sprint while pushing
- **Masking animations**: Hand/arm positions layered on the body animations

---

## The Animation Chain

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐     ┌─────────────┐
│   Item Script   │────►│   Lua Code       │────►│  AnimSet XML    │────►│  .X File    │
│ (attachment)    │     │ (setVariable)    │     │ (conditions)    │     │ (keyframes) │
└─────────────────┘     └──────────────────┘     └─────────────────┘     └─────────────┘

Example flow:
1. Item script: ReplaceInPrimaryHand = CartModel holdingcartright
2. Lua code:    player:setVariable("Weapon", "cart")
3. AnimSet:     <m_Conditions> Weapon = "cart" triggers IdleCart
4. .X file:     AnimationSet Bob_IdleCart contains the actual motion
```

---

## File Structure

```
media/
├── anims_X/Bob/                    # Animation data files
│   ├── _Bob_IdleCart.X
│   ├── _Bob_WalkCart.X
│   ├── _Bob_RunCart.X
│   ├── _Bob_Sprint_Cart.X
│   └── _Bob_IdleToWalk_Cart.X
│
└── AnimSets/player/                # State machine definitions
    ├── idle/
    │   └── idle_cart.xml           # Idle state for carts
    ├── movement/
    │   └── walk_cart.xml           # Walk state for carts
    ├── run/
    │   └── run_cart.xml            # Run state for carts
    ├── sprint/
    │   └── sprint_cart.xml         # Sprint state for carts
    └── maskingright/
        ├── holdingcartright.xml    # Right hand idle position
        ├── walkcartright.xml       # Right hand walk position
        ├── runcartright.xml        # Right hand run position
        └── _sprintcartright.xml    # Right hand sprint position
```

### Naming Conventions

| Type | File Pattern | Example |
|------|--------------|---------|
| .X animation | `_Bob_<Action><Type>.X` | `_Bob_IdleCart.X` |
| Body AnimSet | `<action>_<type>.xml` | `idle_cart.xml` |
| Masking AnimSet | `<action><type><hand>.xml` | `holdingcartright.xml` |

**Note**: Files starting with `_` (underscore) are loaded but may have special handling.

---

## AnimSet XML Reference

### Complete Element Reference

```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode>
    <!-- ===== IDENTITY ===== -->

    <!-- State name (referenced by transitions) -->
    <m_Name>IdleCart</m_Name>

    <!-- Animation to play (matches AnimationSet name in .X file, without path/extension) -->
    <m_AnimName>Bob_IdleCart</m_AnimName>


    <!-- ===== PRIORITY ===== -->

    <!-- Animation priority (higher = preferred when multiple states match) -->
    <m_Priority>10</m_Priority>

    <!-- Condition evaluation priority -->
    <m_ConditionPriority>10</m_ConditionPriority>


    <!-- ===== TIMING ===== -->

    <!-- Playback speed multiplier (1.0 = normal, 0.5 = half speed) -->
    <m_SpeedScale>0.48</m_SpeedScale>

    <!-- Time to blend INTO this animation (seconds) -->
    <m_BlendTime>0.10</m_BlendTime>

    <!-- Time to blend OUT of this animation (seconds) -->
    <m_BlendOutTime>0.20</m_BlendOutTime>


    <!-- ===== SCALARS ===== -->

    <!-- Variables that scale the animation speed -->
    <m_Scalar>IdleSpeed</m_Scalar>
    <m_Scalar2>IdleSpeed</m_Scalar2>

    <!-- For movement: WalkSpeed, WalkInjury, etc. -->


    <!-- ===== AXIS ===== -->

    <!-- Deferred bone axis for rotation calculations -->
    <m_deferredBoneAxis>Y</m_deferredBoneAxis>


    <!-- ===== CONDITIONS (When does this state activate?) ===== -->

    <m_Conditions>
        <m_Name>Weapon</m_Name>           <!-- Variable name -->
        <m_Type>STRING</m_Type>           <!-- STRING, BOOL, or FLOAT -->
        <m_StringValue>cart</m_StringValue>  <!-- Value to match -->
    </m_Conditions>

    <!-- Multiple conditions (all must match): -->
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_StringValue>cart</m_StringValue>
    </m_Conditions>
    <m_Conditions>
        <m_Name>isMoving</m_Name>
        <m_Type>BOOL</m_Type>
        <m_BoolValue>false</m_BoolValue>
    </m_Conditions>


    <!-- ===== 2D BLEND SPACE (for directional movement) ===== -->
    <!--
        CRITICAL: When overriding m_2DBlends in a child AnimSet (via x_extends),
        you MUST include ALL required properties for each blend node:
        - referenceID: Must match the parent's blend node count
        - m_XPos, m_YPos: Position in the 2D blend space
        - m_SpeedScale: Speed multiplier for this blend point

        Without these, movement speed will be extremely slow (0.06 instead of 0.8+)!
        See "2D Blend Critical Requirements" section below.
    -->

    <!-- Define points in a 2D space for blending animations -->
    <m_2DBlends referenceID="1">
        <m_AnimName>Bob_WalkCart</m_AnimName>
        <m_XPos>0.00</m_XPos>    <!-- X axis: WalkInjury (-1 = heavy limp, +1 = light limp) -->
        <m_YPos>1.00</m_YPos>    <!-- Y axis: WalkSpeed (0 = slow, 1 = normal) -->
        <m_SpeedScale>0.80</m_SpeedScale>
    </m_2DBlends>

    <!-- Triangle definitions for blending between 3 points -->
    <m_2DBlendTri>
        <node1>1</node1>
        <node2>2</node2>
        <node3>3</node3>
    </m_2DBlendTri>


    <!-- ===== TRANSITIONS (What states can we go to?) ===== -->

    <m_Transitions>
        <m_Target>walkCart</m_Target>      <!-- Target state name -->
        <m_AnimName>Bob_WalkCart</m_AnimName>  <!-- Optional: transition anim -->
        <m_blendInTime>0.1</m_blendInTime>
        <m_blendOutTime>0.1</m_blendOutTime>
        <m_speedScale>1.0</m_speedScale>
        <m_Priority>10</m_Priority>

        <!-- Optional: conditions for this transition -->
        <m_Conditions>
            <m_Name>isTurningAround</m_Name>
            <m_Type>BOOL</m_Type>
            <m_BoolValue>false</m_BoolValue>
        </m_Conditions>
    </m_Transitions>


    <!-- ===== EVENTS (Footsteps, sounds, etc.) ===== -->

    <m_Events>
        <m_EventName>Footstep</m_EventName>
        <m_TimePc>0.15</m_TimePc>          <!-- % through animation (0.0-1.0) -->
        <m_ParameterValue>walk</m_ParameterValue>  <!-- Event parameter -->
    </m_Events>


    <!-- ===== BONE MASKING (for partial body animations) ===== -->

    <!-- Which bones this animation affects (for masking layers) -->
    <m_SubStateBoneWeights>
        <boneName>Bip01</boneName>
        <weight>1.00</weight>              <!-- 1.0 = full influence -->
    </m_SubStateBoneWeights>
    <m_SubStateBoneWeights>
        <boneName>Bip01_R_Clavicle</boneName>
        <!-- No weight = inherits from parent or uses default -->
    </m_SubStateBoneWeights>

</animNode>
```

### Common Condition Variables

| Variable | Type | Values | Used For |
|----------|------|--------|----------|
| `Weapon` | STRING | `"cart"`, `"handgun"`, etc. | Body animation selection |
| `RightHandMask` | STRING | `"holdingcartright"`, etc. | Right arm masking |
| `LeftHandMask` | STRING | `"holdingcartleft"`, etc. | Left arm masking |
| `isMoving` | BOOL | `true`/`false` | Movement detection |
| `isSprinting` | BOOL | `true`/`false` | Sprint detection |
| `isAiming` | BOOL | `true`/`false` | Aim detection |
| `isTurningAround` | BOOL | `true`/`false` | Turn detection |

### Common Scalar Variables

| Scalar | Used For |
|--------|----------|
| `IdleSpeed` | Idle breathing/sway speed |
| `WalkSpeed` | Walking animation speed (Y axis of movement blend space) |
| `WalkInjury` | Injury-modified walk speed (X axis of movement blend space) |

### 2D Blend Critical Requirements

> **⚠️ CRITICAL**: When using `x_extends` and overriding `m_2DBlends`, you MUST provide complete blend node configurations. Missing properties will cause extremely slow movement (MoveSpeed stuck at 0.06).

**Problem**: If you override `m_2DBlends` like this:
```xml
<!-- WRONG - Missing required properties! -->
<m_2DBlends>
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
</m_2DBlends>
```

The animation system has no blend space coordinates and defaults to minimal movement speed.

**Solution**: Always include ALL required properties:
```xml
<!-- CORRECT - Full blend node configuration -->
<m_2DBlends referenceID="1">
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
    <m_XPos>0.00</m_XPos>
    <m_YPos>0.00</m_YPos>
    <m_SpeedScale>0.80</m_SpeedScale>
</m_2DBlends>
```

**Required Properties for Each Blend Node**:

| Property | Description | Example |
|----------|-------------|---------|
| `referenceID` | Node ID, must match parent's count | `"1"`, `"2"`, etc. |
| `m_AnimName` | Animation to play at this blend point | `Bob_Cart_Walk` |
| `m_XPos` | X position in blend space (-1.0 to 1.0) | `0.00` |
| `m_YPos` | Y position in blend space (0.0 to 1.0) | `1.00` |
| `m_SpeedScale` | Speed multiplier for this node | `0.80` |

**Blend Space Axes** (for movement states):
- **X axis** (`m_Scalar`): Usually `WalkInjury` (-1.0 = heavy limp right, +1.0 = heavy limp left)
- **Y axis** (`m_Scalar2`): Usually `WalkSpeed` (0.0 = slow/stopped, 1.0 = normal speed)

**Match Parent Blend Count**: If the parent AnimSet (e.g., `defaultWalk.xml`) has 6 blend nodes, your child AnimSet should also define 6 blend nodes with matching `referenceID` values.

---

## State Machine Design

### Cart Animation State Machine

```
                    ┌────────────────────────────────────────┐
                    │                                        │
                    ▼                                        │
              ┌──────────┐                                   │
         ┌───►│ IdleCart │◄───┐                              │
         │    └──────────┘    │                              │
         │         │ ▲        │                              │
         │         ▼ │        │                              │
         │    ┌──────────┐    │                              │
         │    │ walkCart │◄───┼──────────────────────────────┤
         │    └──────────┘    │                              │
         │         │ ▲        │                              │
         │         ▼ │        │                              │
         │    ┌──────────┐    │                              │
         ├───►│ runCart  │◄───┤                              │
         │    └──────────┘    │                              │
         │         │ ▲        │                              │
         │         ▼ │        │                              │
         │    ┌────────────┐  │                              │
         └────│sprintCart  │──┴──────────────────────────────┘
              └────────────┘
```

### Transition Rules

Each state needs transitions TO all other cart states:

| From State | Transitions To |
|------------|----------------|
| IdleCart | walkCart, runCart, sprintCart |
| walkCart | IdleCart, runCart, sprintCart |
| runCart | IdleCart, walkCart, sprintCart |
| sprintCart | IdleCart, walkCart, runCart |

---

## Body Animations vs Masking

### Body Animations (Full Body)

- **Purpose**: Control the entire character pose
- **Location**: `player/idle/`, `player/movement/`, `player/run/`, `player/sprint/`
- **Trigger**: `Weapon` variable
- **Example**: Walking animation with arms in pushing position

### Masking Animations (Partial Body)

- **Purpose**: Override specific bones on top of body animation
- **Location**: `player/maskingright/`, `player/maskingleft/`
- **Trigger**: `RightHandMask`, `LeftHandMask` variables
- **Uses**: `m_SubStateBoneWeights` to specify affected bones

### Why Both?

The body animation handles the main pose, but masking allows:
- Different hand positions at different speeds
- Layering hand poses on top of any body animation
- More flexible animation blending

### Bone Hierarchy for Masking

```
Bip01 (root)
├── Bip01_Prop1      # Primary attachment point
├── Bip01_Prop2      # Secondary attachment point
├── Bip01_R_Clavicle # Right shoulder (mask from here for right arm)
│   └── Bip01_R_UpperArm
│       └── Bip01_R_Forearm
│           └── Bip01_R_Hand
└── Bip01_L_Clavicle # Left shoulder (mask from here for left arm)
    └── ...
```

---

## Creating New AnimSets

### Step-by-Step Process

#### 1. Create Your .X Animation Files

Export from Blender/3DS Max with:
- PZ's "Bob" skeleton
- Animation named `Bob_<YourAnimName>`
- 30 FPS, looping (for walk/run/sprint)

The .X file should contain:
```
AnimationSet Bob_IdleCart {
    ...keyframe data...
}
```

#### 2. Create Body Animation XMLs

For each movement state, create an XML in the appropriate folder.

**Template** (see `docs/templates/body_animset_template.xml`):
```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode>
    <m_Name>STATE_NAME</m_Name>
    <m_AnimName>Bob_ANIM_NAME</m_AnimName>
    <m_deferredBoneAxis>Y</m_deferredBoneAxis>
    <m_Priority>10</m_Priority>
    <m_ConditionPriority>10</m_ConditionPriority>
    <m_SpeedScale>1.0</m_SpeedScale>
    <m_BlendTime>0.10</m_BlendTime>

    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_StringValue>cart</m_StringValue>
    </m_Conditions>

    <!-- Add transitions to other states -->
    <m_Transitions>
        <m_Target>OTHER_STATE</m_Target>
        <m_blendInTime>0.1</m_blendInTime>
        <m_blendOutTime>0.1</m_blendOutTime>
    </m_Transitions>
</animNode>
```

#### 3. Create Masking Animation XMLs

For each hand position state, create an XML in `player/maskingright/`.

**Template** (see `docs/templates/masking_animset_template.xml`):
```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode>
    <m_Name>MASK_NAME</m_Name>
    <m_AnimName>Bob_ANIM_NAME</m_AnimName>
    <m_deferredBoneAxis>Y</m_deferredBoneAxis>
    <m_Priority>10</m_Priority>
    <m_ConditionPriority>10</m_ConditionPriority>
    <m_speedScale>1.0</m_speedScale>
    <m_BlendTime>0.050</m_BlendTime>

    <m_Conditions>
        <m_Name>RightHandMask</m_Name>
        <m_Type>STRING</m_Type>
        <m_StringValue>MASK_NAME</m_StringValue>
    </m_Conditions>

    <m_SubStateBoneWeights>
        <boneName>Bip01</boneName>
        <weight>1.00</weight>
    </m_SubStateBoneWeights>
    <m_SubStateBoneWeights>
        <boneName>Bip01_R_Clavicle</boneName>
    </m_SubStateBoneWeights>
    <m_SubStateBoneWeights>
        <boneName>Bip01_Prop1</boneName>
    </m_SubStateBoneWeights>
    <m_SubStateBoneWeights>
        <boneName>Bip01_Prop2</boneName>
    </m_SubStateBoneWeights>

    <!-- Add transitions to other masking states -->
    <m_Transitions>
        <m_Target>OTHER_MASK</m_Target>
        <m_blendInTime>0.05</m_blendInTime>
        <m_blendOutTime>0.05</m_blendOutTime>
    </m_Transitions>
</animNode>
```

#### 4. Update Item Script

```
ReplaceInPrimaryHand = YourCartModel holdingcartright,
ReplaceInSecondHand = YourCartModel holdingcartleft,
```

#### 5. Update Lua Code

```lua
-- Trigger body animations
player:setVariable("Weapon", "cart")

-- Trigger masking animations
player:setVariable("RightHandMask", "holdingcartright")
player:setVariable("LeftHandMask", "holdingcartleft")
```

---

## Wiring to Lua

### Setting Animation Variables

```lua
-- In CartStateHandler.lua or similar

-- When cart is equipped:
player:setVariable("Weapon", "cart")           -- Triggers body anims
player:setVariable("RightHandMask", "holdingcartright")
player:setVariable("LeftHandMask", "holdingcartleft")

-- When cart is unequipped:
player:setVariable("Weapon", "")               -- Clears body anims
player:setVariable("RightHandMask", "")
player:setVariable("LeftHandMask", "")
```

### How Variables Flow

1. Lua calls `player:setVariable("Weapon", "cart")`
2. PZ's animation system checks all AnimSet XMLs
3. Finds XMLs where `<m_Conditions>` match `Weapon = "cart"`
4. Selects highest priority matching state
5. Plays the animation specified by `<m_AnimName>`

---

## Testing & Debugging

### In-Game Testing

1. Enable debug mode
2. Spawn cart: `SaucedCartsDebug.spawnCart("ShoppingCart")`
3. Pick up cart and observe animations
4. Test all movement speeds: walk, jog, sprint
5. Test transitions: stop, start, speed changes

### Common Issues

| Symptom | Likely Cause |
|---------|--------------|
| No animation plays | Condition variable not set, or wrong value |
| T-pose | AnimSet not found, or .X file missing |
| Wrong animation | Priority conflict, wrong m_AnimName |
| Jerky transitions | BlendTime too short, or missing transition |
| Animation too fast/slow | Adjust m_SpeedScale |

### Debug Logging

Add to your Lua code:
```lua
SaucedCarts.debug("Setting Weapon variable to: cart")
player:setVariable("Weapon", "cart")
```

---

## Checklist

### New Animation Checklist

- [ ] **Create .X file** with correct `AnimationSet` name
- [ ] **Place .X file** in `media/anims_X/Bob/`
- [ ] **Create body AnimSet XML** with:
  - [ ] Correct `m_Name` (state name)
  - [ ] Correct `m_AnimName` (matches .X AnimationSet)
  - [ ] `m_Conditions` for `Weapon = "cart"`
  - [ ] `m_Transitions` to all other cart states
  - [ ] `m_Events` for footsteps (if movement anim)
- [ ] **Create masking AnimSet XML** with:
  - [ ] Correct `m_Name` (mask name)
  - [ ] `m_Conditions` for `RightHandMask`
  - [ ] `m_SubStateBoneWeights` for affected bones
  - [ ] `m_Transitions` to other masking states
- [ ] **Update Lua** to set variables on equip/unequip
- [ ] **Update item script** with attachment names
- [ ] **Test in-game** at all movement speeds

### File Naming Checklist

| Component | Naming Pattern | Example |
|-----------|----------------|---------|
| .X file | `_Bob_<Action><Type>.X` | `_Bob_IdleCart.X` |
| AnimationSet (in .X) | `Bob_<Action><Type>` | `Bob_IdleCart` |
| Body XML | `<action>_<type>.xml` | `idle_cart.xml` |
| Masking XML | `<action><type>right.xml` | `holdingcartright.xml` |
| State name (m_Name) | `<action><Type>` | `IdleCart` |
| Mask name (m_Name) | `<action><type>right` | `holdingcartright` |

---

## Quick Reference

### Minimum Viable AnimSet (Body)

```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode>
    <m_Name>IdleCart</m_Name>
    <m_AnimName>Bob_IdleCart</m_AnimName>
    <m_Priority>10</m_Priority>
    <m_ConditionPriority>10</m_ConditionPriority>
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_StringValue>cart</m_StringValue>
    </m_Conditions>
</animNode>
```

### Minimum Viable AnimSet (Masking)

```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode>
    <m_Name>holdingcartright</m_Name>
    <m_AnimName>Bob_IdleCart</m_AnimName>
    <m_Priority>10</m_Priority>
    <m_ConditionPriority>10</m_ConditionPriority>
    <m_Conditions>
        <m_Name>RightHandMask</m_Name>
        <m_Type>STRING</m_Type>
        <m_StringValue>holdingcartright</m_StringValue>
    </m_Conditions>
    <m_SubStateBoneWeights>
        <boneName>Bip01_R_Clavicle</boneName>
    </m_SubStateBoneWeights>
</animNode>
```

---

## Source Evidence

This section documents which vanilla PZ files verify the claims made in this guide.

### Condition Variables

**`Weapon` variable for body animations**
- Source: `media/AnimSets/player/idle/IdleHandgun.xml`
```xml
<m_Conditions>
    <m_Name>Weapon</m_Name>
    <m_Type>STRING</m_Type>
    <m_Value>handgun</m_Value>
</m_Conditions>
```

**`RightHandMask` variable for masking animations**
- Source: `media/AnimSets/player/maskingright/holdingbagright.xml`
```xml
<m_Conditions>
    <m_Name>RightHandMask</m_Name>
    <m_Type>STRING</m_Type>
    <m_Value>holdingbagright</m_Value>
</m_Conditions>
```

**`LeftHandMask` variable for left hand masking**
- Source: `media/AnimSets/player/maskingleft/holdingbagleft.xml`
```xml
<m_Conditions>
    <m_Name>LeftHandMask</m_Name>
    <m_Type>STRING</m_Type>
    <m_Value>holdingbagleft</m_Value>
</m_Conditions>
```

### Bone Weights for Masking

**`m_SubStateBoneWeights` structure and bone names**
- Source: `media/AnimSets/player/maskingright/holdingbagright.xml`
```xml
<m_SubStateBoneWeights>
    <boneName>Bip01</boneName>
    <weight>0.00</weight>
</m_SubStateBoneWeights>
<m_SubStateBoneWeights>
    <boneName>Bip01_R_Clavicle</boneName>
</m_SubStateBoneWeights>
<m_SubStateBoneWeights>
    <boneName>Bip01_Prop1</boneName>
</m_SubStateBoneWeights>
<m_SubStateBoneWeights>
    <boneName>Bip01_Prop2</boneName>
</m_SubStateBoneWeights>
```

### Footstep Events

**`m_Events` structure for footsteps**
- Source: `media/AnimSets/player/movement/defaultWalk.xml`
```xml
<m_Events>
    <m_EventName>Footstep</m_EventName>
    <m_TimePc>0.2</m_TimePc>
    <m_ParameterValue>walk</m_ParameterValue>
</m_Events>
```

### Scalar Variables

**`WalkSpeed`, `WalkInjury` scalars**
- Source: `media/AnimSets/player/movement/defaultWalk.xml`
```xml
<m_Scalar>WalkSpeed</m_Scalar>
<m_Scalar2>WalkInjury</m_Scalar2>
```

### Lua setVariable Usage

**`player:setVariable()` API**
- Source: `media/lua/client/Fishing/FishingManager.lua`
```lua
player:setVariable("fishingCasting", "true")
player:setVariable("FishingRodType", rodType)
```

### Condition Value Format Note

**Important**: Vanilla PZ uses `m_Value` for all condition types:
```xml
<m_Value>handgun</m_Value>
```

Our cart XMLs use `m_StringValue` and `m_BoolValue`:
```xml
<m_StringValue>cart</m_StringValue>
<m_BoolValue>true</m_BoolValue>
```

Both formats work in Build 42. The templates in this repository use the more explicit `m_StringValue`/`m_BoolValue` syntax for clarity.

### File Locations Verified

| Claim | Verified By |
|-------|-------------|
| Body animations in `player/idle/`, `player/movement/`, etc. | `Idle.xml`, `defaultWalk.xml` locations |
| Masking in `player/maskingright/`, `player/maskingleft/` | `holdingbagright.xml`, `holdingbagleft.xml` locations |
| `m_Transitions` structure | All vanilla AnimSet files |
| `m_2DBlends` for directional movement | `media/AnimSets/player/movement/defaultWalk.xml` |
| Priority system (`m_Priority`, `m_ConditionPriority`) | All vanilla AnimSet files |

---

*Last updated: SaucedCarts v1.0.0 | Build 42.13.1+*
