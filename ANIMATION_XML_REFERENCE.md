# Animation XML Technical Reference

This document provides a comprehensive technical reference for Project Zomboid's AnimSet XML system, explaining how each element works internally based on analysis of the decompiled Java source code.

> **Source Evidence**: All explanations reference decompiled Java from Build 42.13.1
> **Location**: `zombie/core/skinnedmodel/advancedanimation/`

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [XML Element Reference](#xml-element-reference)
   - [animNode (Root Element)](#animnode-root-element)
   - [m_Conditions (State Activation)](#m_conditions-state-activation)
   - [m_2DBlends (Blend Space Points)](#m_2dblends-blend-space-points)
   - [m_2DBlendTri (Blend Triangles)](#m_2dblendtri-blend-triangles)
   - [m_Transitions (State Transitions)](#m_transitions-state-transitions)
   - [m_SubStateBoneWeights (Bone Masking)](#m_substateboneweights-bone-masking)
   - [m_Events (Animation Events)](#m_events-animation-events)
   - [Speed Scaling (m_Scalar, m_SpeedScale)](#speed-scaling)
   - [m_deferredBoneAxis (Root Motion)](#m_deferredboneaxis-root-motion)
3. [Layer Architecture](#layer-architecture)
4. [Condition Evaluation Logic](#condition-evaluation-logic)
5. [2D Blend Space Mathematics](#2d-blend-space-mathematics)
6. [SaucedCarts XML Analysis](#saucedcarts-xml-analysis)
7. [Common Patterns](#common-patterns)
8. [Gotchas and Edge Cases](#gotchas-and-edge-cases)

---

## Architecture Overview

Project Zomboid's animation system is a **hierarchical state machine** that processes XML-defined animation nodes.

### Java Class Hierarchy

```
AnimNode.java          - XML parsing, node definition, JAXB annotations
AnimCondition.java     - Condition evaluation (STRING, BOOL, comparisons)
AnimTransition.java    - State transition definitions
Anim2DBlend.java       - Single blend space point
Anim2DBlendPicker.java - Barycentric interpolation across triangles
Anim2DBlendTriangle.java - Triangle definitions for blend space
AnimBoneWeight.java    - Bone masking weights
AnimEvent.java         - Animation event triggers
AnimState.java         - State machine, node selection
LiveAnimNode.java      - Runtime animation playback
```

### Processing Flow

```
┌─────────────────┐    JAXB Parse    ┌─────────────────┐
│   XML File      │ ───────────────► │   AnimNode      │
│ (idle_cart.xml) │                  │   (Java object) │
└─────────────────┘                  └────────┬────────┘
                                              │
                                              ▼
┌─────────────────┐   Check conditions   ┌─────────────────┐
│  Game State     │ ◄──────────────────  │  AnimState      │
│ (variables)     │                      │  (state machine)│
└─────────────────┘                      └────────┬────────┘
                                              │
                                              ▼
┌─────────────────┐   Play animation    ┌─────────────────┐
│  .X File        │ ◄───────────────────│  LiveAnimNode   │
│ (Bob_Cart_Idle) │                     │  (playback)     │
└─────────────────┘                     └─────────────────┘
```

---

## XML Element Reference

### animNode (Root Element)

The root container for an animation state definition.

**Java Source**: `AnimNode.java`

```java
@XmlRootElement(name = "animNode")
public final class AnimNode {
    @XmlElement(name = "m_Name")
    public String name = "";

    @XmlElement(name = "m_AnimName")
    public String animName = "";

    @XmlElement(name = "m_Priority")
    public int priority = 5;  // Default priority

    @XmlElement(name = "m_ConditionPriority")
    public int conditionPriority;

    // ... other fields
}
```

**XML Example**:
```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode>
    <m_Name>IdleCart</m_Name>
    <m_AnimName>Bob_Cart_Idle</m_AnimName>
    <m_Priority>10</m_Priority>
    <m_ConditionPriority>10</m_ConditionPriority>
</animNode>
```

| Element | Type | Default | Purpose |
|---------|------|---------|---------|
| `m_Name` | String | `""` | Unique identifier, referenced by transitions |
| `m_AnimName` | String | `""` | Animation file to play (without path/extension) |
| `m_Priority` | int | `5` | Selection priority when multiple nodes match |
| `m_ConditionPriority` | int | `0` | Order for condition evaluation |

**How Priority Works** (from AnimState.java lines 22-67):

The node selection algorithm is critical for preventing vanilla animations from blending with custom ones:

```java
public List<AnimNode> getAnimNodes(IAnimationVariableSource in_varSource, List<AnimNode> in_nodes) {
    in_nodes.clear();
    // Nodes are PRE-SORTED by addNode() using compareSelectionConditions()
    AnimNode bestNode = null;
    for (int i = 0; i < this.nodes.size(); i++) {
        AnimNode node = this.nodes.get(i);
        // BREAK when we hit a node with LOWER priority than bestNode
        if (bestNode != null && bestNode.compareSelectionConditions(node) > 0) {
            break;  // Stop checking - we've found all matching high-priority nodes
        }
        if (node.checkConditions(in_varSource)) {
            bestNode = node;
            in_nodes.add(node);  // ALL matching nodes at SAME priority are added
        }
    }
    return in_nodes;
}
```

**Sorting logic** (from AnimNode.java lines 279-291):

```java
public static int compareSelectionConditions(AnimNode a, AnimNode b) {
    // 1. Abstract nodes always come last
    if (a.isAbstract() != b.isAbstract()) {
        return a.isAbstract() ? -1 : 1;
    }
    // 2. Higher conditionPriority comes FIRST (returns positive)
    if (a.conditionPriority < b.conditionPriority) return -1;
    if (a.conditionPriority > b.conditionPriority) return 1;
    // 3. More conditions = higher priority (tiebreaker)
    if (a.conditions.length < b.conditions.length) return -1;
    if (a.conditions.length > b.conditions.length) return 1;
    return 0;
}
```

**Key insight**: With `conditionPriority=10` on your custom node and `conditionPriority=0` (default) on vanilla:
1. Your node is sorted first (higher priority)
2. When it matches, the loop breaks before checking vanilla
3. Only your animation activates - no blending with vanilla injury/limp animations

**File Loading Order** (from ZomboidFileSystem.java lines 1255-1266):

```java
public void walkGameAndModFiles(String relPath, ...) {
    // 1. Vanilla files load FIRST
    this.walkGameAndModFilesInternal(this.base.canonicalFile, relPath, ...);
    // 2. Mod files load SECOND
    for (String modID : this.getModIDs()) {
        this.walkGameAndModFilesInternal(mod.getCommonDir(), relPath, ...);
    }
}
// In resolveAllFiles(): if (!result.contains(relPath3)) - SKIPS duplicates
```

**Critical**: Vanilla AnimSet files load first. Mod files with the SAME relative path are SKIPPED. You cannot override vanilla AnimSets by placing modified copies in your mod - use `conditionPriority` instead.

---

### m_Conditions (State Activation)

Conditions determine when an animation node becomes active. All conditions must pass (AND logic) unless separated by OR.

**Java Source**: `AnimCondition.java` (lines 114-185)

```java
@XmlType(name = "AnimCondition")
public final class AnimCondition {
    @XmlElement(name = "m_Name")
    public String name;

    @XmlElement(name = "m_Type")
    public Type type;

    @XmlElement(name = "m_Value")
    public String value;  // Parsed based on type

    @XmlEnum
    public static enum Type {
        STRING,   // Case-insensitive string equality
        STRNEQ,   // String not-equals
        BOOL,     // Boolean equality
        EQU,      // Float equals
        NEQ,      // Float not-equals
        LESS,     // Float less-than
        GTR,      // Float greater-than
        ABSLESS,  // Absolute value less-than
        ABSGTR,   // Absolute value greater-than
        OR        // Logical OR separator
    }
}
```

**Condition Check Logic** (AnimCondition.java:114-165):
```java
public boolean check(IAnimationVariableSource varSource) {
    IAnimationVariableSlot slot = this.variableReference.getVariable(varSource);

    switch (this.type) {
        case STRING:
            return StringUtils.equalsIgnoreCase(this.stringValue, slot.getValueString());
        case STRNEQ:
            return !StringUtils.equalsIgnoreCase(this.stringValue, slot.getValueString());
        case BOOL:
            return slot.getValueBool() == this.boolValue;
        case EQU:
            return this.floatValue == slot.getValueFloat();
        case NEQ:
            return this.floatValue != slot.getValueFloat();
        case LESS:
            return slot.getValueFloat() < this.floatValue;
        case GTR:
            return slot.getValueFloat() > this.floatValue;
        case ABSLESS:
            return PZMath.abs(slot.getValueFloat()) < this.floatValue;
        case ABSGTR:
            return PZMath.abs(slot.getValueFloat()) > this.floatValue;
    }
    return false;
}
```

**AND/OR Logic** (AnimCondition.java:168-185):
```java
public static boolean pass(IAnimationVariableSource varSource, AnimCondition[] conditions) {
    boolean valid = true;

    for (AnimCondition condition : conditions) {
        if (condition.type == Type.OR) {
            if (valid) {
                break;  // OR short-circuits when previous group passed
            }
            valid = true;  // Reset for next group
        } else {
            valid = valid && condition.check(varSource);  // AND within group
        }
    }

    return valid;
}
```

**XML Examples**:

```xml
<!-- Simple string condition -->
<m_Conditions>
    <m_Name>Weapon</m_Name>
    <m_Type>STRING</m_Type>
    <m_Value>cart</m_Value>
</m_Conditions>

<!-- Boolean condition -->
<m_Conditions>
    <m_Name>isMoving</m_Name>
    <m_Type>BOOL</m_Type>
    <m_Value>true</m_Value>
</m_Conditions>

<!-- Multiple AND conditions (all must pass) -->
<m_Conditions>
    <m_Name>RightHandMask</m_Name>
    <m_Type>STRING</m_Type>
    <m_Value>holdingcartright</m_Value>
</m_Conditions>
<m_Conditions>
    <m_Name>isMoving</m_Name>
    <m_Type>BOOL</m_Type>
    <m_Value>true</m_Value>
</m_Conditions>
<m_Conditions>
    <m_Name>isRunning</m_Name>
    <m_Type>BOOL</m_Type>
    <m_Value>false</m_Value>
</m_Conditions>

<!-- Float comparison -->
<m_Conditions>
    <m_Name>WalkSpeed</m_Name>
    <m_Type>GTR</m_Type>
    <m_Value>0.5</m_Value>
</m_Conditions>

<!-- OR logic (either group can pass) -->
<m_Conditions>
    <m_Name>Weapon</m_Name>
    <m_Type>STRING</m_Type>
    <m_Value>cart</m_Value>
</m_Conditions>
<m_Conditions>
    <m_Type>OR</m_Type>
</m_Conditions>
<m_Conditions>
    <m_Name>Weapon</m_Name>
    <m_Type>STRING</m_Type>
    <m_Value>wheelbarrow</m_Value>
</m_Conditions>
```

**Common Animation Variables**:

| Variable | Type | Values | Set By |
|----------|------|--------|--------|
| `Weapon` | STRING | `"cart"`, `"handgun"`, `"2handed"`, etc. | Lua: `player:setVariable()` |
| `RightHandMask` | STRING | `"holdingcartright"`, etc. | Lua: `player:setVariable()` |
| `LeftHandMask` | STRING | `"holdingcartleft"`, etc. | Lua: `player:setVariable()` |
| `isMoving` | BOOL | `true`/`false` | Engine (automatic) |
| `isRunning` | BOOL | `true`/`false` | Engine (automatic) |
| `isSprinting` | BOOL | `true`/`false` | Engine (automatic) |
| `Aim` | BOOL | `true`/`false` | Engine (automatic) |
| `sneaking` | BOOL | `true`/`false` | Engine (automatic) |
| `isTurningAround` | BOOL | `true`/`false` | Engine (automatic) |

---

### m_2DBlends (Blend Space Points)

Defines points in a 2D coordinate space for animation blending. The engine interpolates between animations based on current X/Y input values.

**Java Source**: `Anim2DBlend.java`

```java
@XmlType(name = "Anim2DBlend")
public final class Anim2DBlend {
    @XmlElement(name = "m_AnimName")
    public String animName = "";

    @XmlElement(name = "m_XPos")
    public float posX;  // X position in blend space

    @XmlElement(name = "m_YPos")
    public float posY;  // Y position in blend space

    @XmlElement(name = "m_SpeedScale")
    public float speedScale = 1.0F;  // Per-point speed multiplier

    @XmlAttribute(name = "referenceID")
    @XmlID
    public String referenceId;  // Used by triangles to reference this point
}
```

**XML Example**:
```xml
<!-- Define 6 blend points for directional movement -->
<m_2DBlends referenceID="1">
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
    <m_XPos>0.00</m_XPos>    <!-- Center X -->
    <m_YPos>1.00</m_YPos>    <!-- Full forward -->
    <m_SpeedScale>0.80</m_SpeedScale>
</m_2DBlends>
<m_2DBlends referenceID="2">
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
    <m_XPos>0.50</m_XPos>    <!-- Right strafe -->
    <m_YPos>1.00</m_YPos>
    <m_SpeedScale>0.80</m_SpeedScale>
</m_2DBlends>
<m_2DBlends referenceID="3">
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
    <m_XPos>-0.50</m_XPos>   <!-- Left strafe -->
    <m_YPos>1.00</m_YPos>
    <m_SpeedScale>0.80</m_SpeedScale>
</m_2DBlends>
```

**Coordinate System**:
```
         Y (typically WalkSpeed)
         ▲
    1.0  │    Forward movement (full speed)
         │
    0.5  │    Half speed
         │
    0.0  ├────────────────────► X (typically WalkInjury / strafe)
        -1.0    0.0    1.0
         Left  Center  Right
```

| Axis | Typical Variable | Range | Meaning |
|------|-----------------|-------|---------|
| X | `WalkInjury` or strafe | -1.0 to 1.0 | Left (-) to Right (+) |
| Y | `WalkSpeed` | 0.0 to 1.0 | Stopped (0) to Full speed (1) |

---

### m_2DBlendTri (Blend Triangles)

Defines triangles that connect three blend points. The engine determines which triangle contains the current (X, Y) position and uses barycentric interpolation to blend between the three corner animations.

**Java Source**: `Anim2DBlendTriangle.java`

```java
@XmlType(name = "Anim2DBlendTriangle")
public final class Anim2DBlendTriangle {
    @XmlIDREF
    @XmlElement(name = "node1")
    public Anim2DBlend node1;

    @XmlIDREF
    @XmlElement(name = "node2")
    public Anim2DBlend node2;

    @XmlIDREF
    @XmlElement(name = "node3")
    public Anim2DBlend node3;

    public boolean Contains(float x, float y) {
        // Point-in-triangle test using barycentric coordinates
        return PointInTriangle(x, y,
            node1.posX, node1.posY,
            node2.posX, node2.posY,
            node3.posX, node3.posY);
    }
}
```

**XML Example**:
```xml
<!-- Triangles reference blend points by their referenceID -->
<m_2DBlendTri>
    <node1>1</node1>   <!-- Forward center -->
    <node2>2</node2>   <!-- Forward right -->
    <node3>6</node3>   <!-- Center/idle -->
</m_2DBlendTri>
<m_2DBlendTri>
    <node1>1</node1>   <!-- Forward center -->
    <node2>3</node2>   <!-- Forward left -->
    <node3>6</node3>   <!-- Center/idle -->
</m_2DBlendTri>
```

**Visual Representation**:
```
     ref2 (0.5, 1.0)          ref1 (0.0, 1.0)          ref3 (-0.5, 1.0)
         ●━━━━━━━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━━━━━━━●
          ╲        Tri 1       ╱ ╲       Tri 2        ╱
           ╲                  ╱   ╲                  ╱
            ╲                ╱     ╲                ╱
             ╲              ╱       ╲              ╱
              ╲            ╱         ╲            ╱
               ╲          ╱           ╲          ╱
                ╲        ╱             ╲        ╱
                 ╲      ╱               ╲      ╱
                  ╲    ╱                 ╲    ╱
                   ╲  ╱                   ╲  ╱
                    ╲╱                     ╲╱
                     ●━━━━━━━━━━━━━━━━━━━━━━●
                ref6 (0.0, 0.0)       (idle point)
```

---

### m_Transitions (State Transitions)

Defines how to transition from this animation state to another. Transitions can have their own conditions, blend times, and transition animations.

**Java Source**: `AnimTransition.java`

```java
@XmlType(name = "AnimTransition")
public final class AnimTransition {
    @XmlElement(name = "m_Source")
    public String source;  // Optional: source state filter

    @XmlElement(name = "m_Target")
    public String target;  // Target state name (required)

    @XmlElement(name = "m_AnimName")
    public String animName;  // Optional: play this during transition

    @XmlElement(name = "m_blendInTime")
    public float blendInTime = Float.POSITIVE_INFINITY;  // Seconds to blend in

    @XmlElement(name = "m_blendOutTime")
    public float blendOutTime = Float.POSITIVE_INFINITY;  // Seconds to blend out

    @XmlElement(name = "m_speedScale")
    public float speedScale = Float.POSITIVE_INFINITY;  // Transition anim speed

    @XmlElement(name = "m_Priority")
    public int priority;  // Higher = preferred

    @XmlElement(name = "m_Conditions")
    public AnimCondition[] conditions = new AnimCondition[0];  // Optional gate
}
```

**Transition Finding** (AnimNode.java:215-234):
```java
public AnimTransition findTransitionTo(IAnimationVariableSource varSource, AnimNode toNode) {
    for (AnimTransition trans : this.transitions) {
        // Check if target matches
        if (StringUtils.equalsIgnoreCase(trans.target, toNode.name)) {
            trans.parse(this, toNode);
            // Check conditions (if any)
            if (AnimCondition.pass(varSource, trans.conditions)) {
                return trans;
            }
        }
    }
    return null;  // No matching transition found
}
```

**XML Example**:
```xml
<!-- Simple transition to idle -->
<m_Transitions>
    <m_Target>IdleCart</m_Target>
    <m_blendInTime>0.1</m_blendInTime>
    <m_blendOutTime>0.1</m_blendOutTime>
</m_Transitions>

<!-- Transition with bridge animation -->
<m_Transitions>
    <m_Target>walkCart</m_Target>
    <m_AnimName>Bob_Cart_IdleToWalk</m_AnimName>
    <m_blendInTime>0.1</m_blendInTime>
    <m_blendOutTime>0.1</m_blendOutTime>
    <m_speedScale>1.0</m_speedScale>
</m_Transitions>

<!-- Conditional transition -->
<m_Transitions>
    <m_Target>runCart</m_Target>
    <m_blendInTime>0.1</m_blendInTime>
    <m_Conditions>
        <m_Name>isTurningAround</m_Name>
        <m_Type>BOOL</m_Type>
        <m_Value>false</m_Value>
    </m_Conditions>
</m_Transitions>
```

**Blend Time Semantics**:

| Property | Meaning | Typical Values |
|----------|---------|----------------|
| `m_blendInTime` | Time to fade INTO the transition/target | 0.03 - 0.2 seconds |
| `m_blendOutTime` | Time to fade OUT of current state | 0.03 - 0.5 seconds |
| `m_speedScale` | Speed of transition animation (if specified) | 0.5 - 1.0 |

**Design Patterns**:
- **Fast blends (0.03s)**: Responsive, snappy transitions (walk↔run)
- **Medium blends (0.1s)**: Smooth, natural transitions (idle↔walk)
- **Slow blends (0.5s)**: Momentum feel (run↔sprint)

---

### m_SubStateBoneWeights (Bone Masking)

Defines which bones this animation affects and their influence weight. Used for masking layers that overlay partial animations on the base body animation.

**Java Source**: `AnimBoneWeight.java`

```java
@XmlType(name = "AnimBoneWeight")
public final class AnimBoneWeight {
    @XmlElement(name = "boneName")
    public String boneName;

    @XmlElement(name = "weight")
    public float weight = 1.0F;  // 0.0 = no influence, 1.0 = full override

    @XmlElement(name = "includeDescendants")
    public boolean includeDescendants = true;  // Apply to child bones
}
```

**Default Bone Weights** (AnimNode.java:166-172):
```java
// If no bone weights specified, these defaults are applied
if (parsedNode.subStateBoneWeights.isEmpty()) {
    parsedNode.subStateBoneWeights.add(new AnimBoneWeight("Bip01_Spine1", 0.5F));
    parsedNode.subStateBoneWeights.add(new AnimBoneWeight("Bip01_Neck", 1.0F));
    parsedNode.subStateBoneWeights.add(new AnimBoneWeight("Bip01_BackPack", 1.0F));
    parsedNode.subStateBoneWeights.add(new AnimBoneWeight("Bip01_Prop1", 1.0F));
    parsedNode.subStateBoneWeights.add(new AnimBoneWeight("Bip01_Prop2", 1.0F));
}
```

**XML Example**:
```xml
<!-- Only affect the right hand prop bone -->
<m_SubStateBoneWeights>
    <boneName>Bip01_Prop1</boneName>
    <weight>1.00</weight>
</m_SubStateBoneWeights>

<!-- Partial influence on spine, full on arm -->
<m_SubStateBoneWeights>
    <boneName>Bip01_Spine1</boneName>
    <weight>0.50</weight>
</m_SubStateBoneWeights>
<m_SubStateBoneWeights>
    <boneName>Bip01_R_Clavicle</boneName>
    <weight>1.00</weight>
</m_SubStateBoneWeights>
```

**PZ Skeleton Hierarchy** (relevant bones):
```
Bip01 (root)
├── Bip01_Prop1      ← Primary attachment (right hand items)
├── Bip01_Prop2      ← Secondary attachment (left hand items)
├── Bip01_Spine
│   └── Bip01_Spine1 ← Upper torso
│       └── Bip01_Neck
│           └── Bip01_Head
├── Bip01_R_Clavicle ← Right shoulder (mask from here for right arm)
│   └── Bip01_R_UpperArm
│       └── Bip01_R_Forearm
│           └── Bip01_R_Hand
├── Bip01_L_Clavicle ← Left shoulder
│   └── ...
└── Bip01_Pelvis
    └── (leg bones)
```

**Weight Blending**:
- `weight=1.0`: This animation completely overrides the base animation for this bone
- `weight=0.5`: 50% base animation, 50% this animation
- `weight=0.0`: Base animation only (bone not affected)
- `includeDescendants=true`: Weight applies to all child bones too

---

### m_Events (Animation Events)

Defines events that trigger at specific points during animation playback. Common uses include footstep sounds, weapon collision activation, and variable changes.

**Java Source**: `AnimEvent.java`

```java
@XmlType(name = "AnimEvent")
public class AnimEvent {
    @XmlElement(name = "m_EventName")
    public String eventName;  // Event type identifier

    @XmlElement(name = "m_Time")
    public AnimEventTime time = AnimEventTime.PERCENTAGE;  // When to trigger

    @XmlElement(name = "m_TimePc")
    public float timePc;  // 0.0 to 1.0 (percentage through animation)

    @XmlElement(name = "m_ParameterValue")
    public String parameterValue;  // Event-specific data

    @XmlEnum
    public static enum AnimEventTime {
        PERCENTAGE,  // Trigger at timePc% through animation
        START,       // Trigger at animation start
        END          // Trigger at animation end
    }
}
```

**Special Event Types** (AnimNode.java:147-158):
```java
// During parsing, special events are converted to subclasses
PZArrayUtil.forEachReplace(parsedNode.events, event -> {
    if ("SetVariable".equalsIgnoreCase(event.eventName)) {
        return new AnimEventSetVariable(event);  // Sets a variable
    } else if ("FlagWhileAlive".equalsIgnoreCase(event.eventName)) {
        return new AnimEventFlagWhileAlive(event);  // Keeps flag active while playing
    }
    return event;
});
// Events are sorted by timePc for correct firing order
parsedNode.events.sort(eventsComparator);
```

**XML Examples**:
```xml
<!-- Footstep at 15% and 60% of animation -->
<m_Events>
    <m_EventName>Footstep</m_EventName>
    <m_TimePc>0.15</m_TimePc>
    <m_ParameterValue>walk</m_ParameterValue>
</m_Events>
<m_Events>
    <m_EventName>Footstep</m_EventName>
    <m_TimePc>0.60</m_TimePc>
    <m_ParameterValue>walk</m_ParameterValue>
</m_Events>

<!-- Set a variable at 30% through animation -->
<m_Events>
    <m_EventName>SetVariable</m_EventName>
    <m_TimePc>0.30</m_TimePc>
    <m_ParameterValue>weaponCollisionActive=true</m_ParameterValue>
</m_Events>

<!-- Keep a flag active while animation plays -->
<m_Events>
    <m_EventName>FlagWhileAlive</m_EventName>
    <m_Time>START</m_Time>
    <m_ParameterValue>isAttacking=true</m_ParameterValue>
</m_Events>
```

**Footstep ParameterValue Options**:

| Value | Sound Type | Noise Level |
|-------|------------|-------------|
| `walk` | Walking footsteps | Quiet |
| `run` | Running footsteps | Medium |
| `sprint` | Sprinting footsteps | Loud |

---

### Speed Scaling

Multiple mechanisms control animation playback speed.

**Java Source**: `AnimNode.java`

```java
@XmlElement(name = "m_SpeedScale")
public String speedScale = "";  // Can be literal or variable name

@XmlElement(name = "m_Scalar")
public String scalar = "";  // First speed multiplier variable

@XmlElement(name = "m_Scalar2")
public String scalar2 = "";  // Second speed multiplier variable

@XmlElement(name = "m_SpeedScaleRandomMultiplierMin")
public float speedScaleRandomMultiplierMin = 1.0F;

@XmlElement(name = "m_SpeedScaleRandomMultiplierMax")
public float speedScaleRandomMultiplierMax = 1.0F;

// Parsing logic
public float getSpeedScale(IAnimationVariableSource varSource) {
    // If speedScale is a number, use it directly
    if (this.speedScaleF != Float.POSITIVE_INFINITY) {
        return this.speedScaleF;
    }
    // Otherwise, look up variable value
    return varSource.getVariableFloat(this.speedScale, 1.0F);
}
```

**Final Speed Calculation**:
```
finalSpeed = m_SpeedScale × m_Scalar × m_Scalar2 × randomMultiplier × blend.speedScale
```

**XML Example**:
```xml
<m_SpeedScale>0.96</m_SpeedScale>    <!-- Base speed: 96% -->
<m_Scalar>WalkInjury</m_Scalar>      <!-- Multiplied by injury factor -->
<m_Scalar2>WalkSpeed</m_Scalar2>     <!-- Multiplied by walk speed -->

<!-- Each blend point can also have its own speed -->
<m_2DBlends referenceID="1">
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
    <m_SpeedScale>0.80</m_SpeedScale>  <!-- This point plays at 80% -->
</m_2DBlends>
```

**Common Scalar Variables**:

| Variable | Purpose | Typical Range |
|----------|---------|---------------|
| `IdleSpeed` | Idle breathing/sway | 0.8 - 1.2 |
| `WalkSpeed` | Walking pace | 0.0 - 1.0 |
| `WalkInjury` | Injury slowdown | 0.5 - 1.0 |

---

### m_deferredBoneAxis (Root Motion)

Controls how root motion (character movement) is extracted from the animation itself rather than being driven by game logic. This is the **critical setting** for animation-driven movement.

**Java Source**: `AnimNode.java` (lines 56-65)

```java
@XmlElement(name = "m_DeferredBoneName")
public String deferredBoneName = "Translation_Data";  // Bone to extract movement from

@XmlElement(name = "m_deferredBoneAxis")
public BoneAxis deferredBoneAxis = BoneAxis.Y;  // Which axis mapping to use

@XmlElement(name = "m_useDeferedRotation")
public boolean useDeferedRotation;  // Extract rotation too?

@XmlElement(name = "m_useDeferredMovement")
public boolean useDeferredMovement = true;  // Extract position? (default: true)

@XmlElement(name = "m_deferredRotationScale")
public float deferredRotationScale = 1.0F;  // Rotation multiplier
```

### How Root Motion Works

The animation system extracts movement from a special bone called `Translation_Data`. Each frame, the bone's position delta is converted to character movement.

**Java Source**: `AnimationTrack.java` (lines 324-329)

```java
private Vector2 getDeferredMovement(Vector3f bonePos, Vector2 out_deferredPos) {
    if (this.deferredBoneAxis == BoneAxis.Y) {
        out_deferredPos.set(bonePos.x, -bonePos.z);  // Forward = -Z axis
    } else {
        out_deferredPos.set(bonePos.x, bonePos.y);   // Forward = Y axis
    }
    return out_deferredPos;
}
```

**Java Source**: `IsoGameCharacter.java` (line 1629)

```java
// This is where the character actually moves based on the bone position
if (this.isDeferredMovementEnabled()) {
    this.MoveUnmodded(dMovement);  // Applies the extracted movement
}
```

### BoneAxis Mapping (Critical!)

The `m_deferredBoneAxis` setting determines **which bone axis is read as forward movement**:

| Setting | Bone Position Read | Forward Direction | Use When |
|---------|-------------------|-------------------|----------|
| `Y` (default) | `(bonePos.x, -bonePos.z)` | **-Z axis** is forward | Animation moves bone on -Z axis |
| `Z` | `(bonePos.x, bonePos.y)` | **Y axis** is forward | Animation moves bone on Y axis |

### Blender to PZ Coordinate Mapping

Blender and PZ have different coordinate systems. When exporting animations with root motion:

| Blender Axis | PZ Bone Axis | deferredBoneAxis Setting |
|--------------|--------------|--------------------------|
| **Y forward** (Blender default) | Becomes Y in PZ | Use `Z` |
| **-Y forward** | Becomes -Y in PZ | Use `Z` (may need invert) |
| **Z forward** | Becomes Z in PZ | Use `Y` (reads -Z as forward) |

**Common Issue**: If your character rotates and falls over when walking, you have a coordinate mismatch. Try switching between `Y` and `Z`.

### XML Examples

```xml
<!-- Default: reads -Z as forward (vanilla PZ convention) -->
<m_deferredBoneAxis>Y</m_deferredBoneAxis>

<!-- For Blender Y-forward animations -->
<m_deferredBoneAxis>Z</m_deferredBoneAxis>

<!-- Disable root motion entirely (movement from game logic only) -->
<m_useDeferredMovement>false</m_useDeferredMovement>

<!-- Use a different bone for root motion -->
<m_DeferredBoneName>CustomRootBone</m_DeferredBoneName>
```

### Complete Root Motion Setup

For animation-driven movement to work, you need:

1. **Translation_Data bone** in your animation that moves forward over time
2. **m_useDeferredMovement = true** (default, don't set to false)
3. **Correct m_deferredBoneAxis** matching your animation's forward axis

```xml
<?xml version="1.0" encoding="utf-8"?>
<animNode>
    <m_Name>walkCart</m_Name>
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
    <m_SpeedScale>1.04</m_SpeedScale>
    <m_deferredBoneAxis>Z</m_deferredBoneAxis>  <!-- For Y-forward Blender animations -->
    <m_Conditions>
        <m_Name>Weapon</m_Name>
        <m_Type>STRING</m_Type>
        <m_Value>cart</m_Value>
    </m_Conditions>
    <!-- transitions... -->
</animNode>
```

### Debugging Root Motion Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Character doesn't move | `m_useDeferredMovement=false` or missing Translation_Data bone | Add bone, ensure setting is true |
| Character rotates/falls over | Wrong `m_deferredBoneAxis` for your animation | Switch between Y and Z |
| Movement is backwards | Animation has inverted forward direction | Flip bone animation direction in Blender |
| Movement is sideways | Wrong axis animated in Blender | Re-animate on correct axis or adjust setting |

### SaucedCarts Cart Animations

SaucedCarts uses `m_deferredBoneAxis=Z` because our cart animations were created in Blender with Y-forward convention:

```xml
<!-- walk_cart.xml, run_cart.xml, sprint_cart.xml all use: -->
<m_deferredBoneAxis>Z</m_deferredBoneAxis>
```

This reads `bonePos.y` as forward movement, matching our Blender export settings

---

## Layer Architecture

PZ's animation system supports multiple layers that blend together:

```
┌─────────────────────────────────────────────────────────────────┐
│                    MASKING LAYER (Partial Override)             │
│  Condition: RightHandMask == "holdingcartright"                 │
│  Affects: Bip01_Prop1 ONLY (weight=1.0)                         │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │holdingcartright │  │ walkcartright   │  │ runcartright    │  │
│  │  (idle hand)    │  │  (walk hand)    │  │  (run hand)     │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │ Blends on top of
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BASE LAYER (Full Body)                       │
│  Condition: Weapon == "cart"                                    │
│  Affects: All bones                                             │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │  IdleCart   │→ │  walkCart   │→ │   runCart   │→ │sprintCart│ │
│  │ (standing)  │  │  (walking)  │  │  (jogging)  │  │(fastest) │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### How Layers Combine

1. **Base layer** plays full-body animation (legs, torso, arms)
2. **Masking layer** overrides specific bones (e.g., just the right hand)
3. Final pose = base pose with masked bones replaced by masking layer

### When to Use Masking

- **Use masking** when hand/arm pose should be independent of body movement
- **Don't use masking** when the entire pose is custom for your item

---

## Condition Evaluation Logic

Understanding how PZ evaluates conditions is critical for debugging.

### Evaluation Order

1. Nodes are checked in **conditionPriority** order (highest first)
2. Within each node, conditions are evaluated sequentially
3. All conditions must pass (AND) unless separated by OR type
4. First fully-matching node wins (based on priority)

### Example Evaluation

Given this masking node:
```xml
<m_Conditions>
    <m_Name>RightHandMask</m_Name>
    <m_Type>STRING</m_Type>
    <m_Value>holdingcartright</m_Value>
</m_Conditions>
<m_Conditions>
    <m_Name>isMoving</m_Name>
    <m_Type>BOOL</m_Type>
    <m_Value>true</m_Value>
</m_Conditions>
<m_Conditions>
    <m_Name>isRunning</m_Name>
    <m_Type>BOOL</m_Type>
    <m_Value>true</m_Value>
</m_Conditions>
<m_Conditions>
    <m_Name>isSprinting</m_Name>
    <m_Type>BOOL</m_Type>
    <m_Value>false</m_Value>
</m_Conditions>
```

This activates when:
- `RightHandMask == "holdingcartright"` AND
- `isMoving == true` AND
- `isRunning == true` AND
- `isSprinting == false`

This precisely targets the "jogging" state (moving + running but not sprinting).

---

## 2D Blend Space Mathematics

The engine uses **barycentric coordinates** to interpolate between animations.

### Triangle Selection

**Java Source**: `Anim2DBlendPicker.java:97-156`

```java
public PickResults Pick(float x, float y, PickResults result) {
    // 1. Find which triangle contains point (x, y)
    for (Anim2DBlendTriangle tri : this.tris) {
        if (tri.Contains(x, y)) {
            result.numNodes = 3;
            result.node1 = tri.node1;
            result.node2 = tri.node2;
            result.node3 = tri.node3;

            // 2. Calculate barycentric weights
            // These determine how much of each corner animation to use
            float v1x = tri.node1.posX, v1y = tri.node1.posY;
            float v2x = tri.node2.posX, v2y = tri.node2.posY;
            float v3x = tri.node3.posX, v3y = tri.node3.posY;

            float denom = (v2y - v3y) * (v1x - v3x) + (v3x - v2x) * (v1y - v3y);
            result.scale1 = ((v2y - v3y) * (x - v3x) + (v3x - v2x) * (y - v3y)) / denom;
            result.scale2 = ((v3y - v1y) * (x - v3x) + (v1x - v3x) * (y - v3y)) / denom;
            result.scale3 = 1.0F - result.scale1 - result.scale2;

            return result;
        }
    }

    // 3. If outside all triangles, extrapolate from nearest edge
    // ...
}
```

### Visual Example

If the player is moving forward-right at 75% speed, the point might be (0.3, 0.75):

```
Y
1.0  ●─────────────●─────────────●
     │╲           ╱│╲           ╱│
     │ ╲         ╱ │ ╲         ╱ │
     │  ╲       ╱  │  ╲       ╱  │
     │   ╲     ╱   │   ╲     ╱   │
     │    ╲   ╱    │    ╲   ╱    │
     │     ╲ ╱  ×  │     ╲ ╱     │  × = current position (0.3, 0.75)
     │      ●      │      ●      │
     │     ╱ ╲     │     ╱ ╲     │
0.0  ●────────────●────────────●
    -1.0   -0.5   0.0   0.5   1.0  X
```

The engine finds the triangle containing ×, then calculates:
- ~40% of forward-center animation
- ~45% of forward-right animation
- ~15% of center-right animation

---

## SaucedCarts XML Analysis

### idle_cart.xml Summary

| Section | Purpose |
|---------|---------|
| `m_Name=IdleCart` | State identifier |
| `m_AnimName=Bob_Cart_Idle` | Plays idle animation |
| `m_SpeedScale=0.48` | Slow, relaxed idle (48% speed) |
| `m_Conditions: Weapon=cart` | Only active when holding cart |
| `m_2DBlends` (3 points) | Placeholder - all same animation |
| `m_Transitions` (4) | Can go to walk, run, sprint, turn_idle |

### Movement XMLs Pattern

All movement XMLs (walk, run, sprint) follow the same pattern:
- Same animation file (`Bob_Cart_Walk`) at different speeds
- Injury and speed scalars for natural variation
- Footstep events at 15% and 60% of cycle
- Transitions to all other cart states

### Masking XMLs Pattern

All masking XMLs:
- Condition on `RightHandMask == "holdingcartright"`
- Additional movement state conditions (isMoving, isRunning, isSprinting)
- Negative conditions (Aim=false, sneaking=false) to block conflicting states
- Only affect `Bip01_Prop1` bone at weight 1.0
- Fast 50ms blend times for responsive hand movement

---

## Common Patterns

### Pattern: Movement State Exclusion

Use multiple conditions to precisely target one movement state:

```xml
<!-- Walk only (not run, not sprint, not sneak) -->
<m_Conditions><m_Name>isMoving</m_Name><m_Type>BOOL</m_Type><m_Value>true</m_Value></m_Conditions>
<m_Conditions><m_Name>isRunning</m_Name><m_Type>BOOL</m_Type><m_Value>false</m_Value></m_Conditions>
<m_Conditions><m_Name>isSprinting</m_Name><m_Type>BOOL</m_Type><m_Value>false</m_Value></m_Conditions>
<m_Conditions><m_Name>sneaking</m_Name><m_Type>BOOL</m_Type><m_Value>false</m_Value></m_Conditions>
```

### Pattern: Momentum Transitions

Use asymmetric blend times to create momentum feel:

```xml
<!-- Sprint → Run: slow blend (momentum) -->
<m_Transitions>
    <m_Target>runCart</m_Target>
    <m_blendInTime>0.5</m_blendInTime>
    <m_blendOutTime>0.5</m_blendOutTime>
</m_Transitions>

<!-- Sprint → Idle: fast blend but slow anim (dramatic stop) -->
<m_Transitions>
    <m_Target>IdleCart</m_Target>
    <m_blendInTime>0.03</m_blendInTime>
    <m_speedScale>0.5</m_speedScale>
</m_Transitions>
```

### Pattern: Single Animation, Multiple Points

When you only have one animation but need blend space compatibility:

```xml
<!-- All points use same animation -->
<m_2DBlends referenceID="1">
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
    <m_XPos>0.00</m_XPos><m_YPos>1.00</m_YPos>
</m_2DBlends>
<m_2DBlends referenceID="2">
    <m_AnimName>Bob_Cart_Walk</m_AnimName>
    <m_XPos>0.50</m_XPos><m_YPos>1.00</m_YPos>
</m_2DBlends>
<!-- ... more points with same animation ... -->
```

---

## Gotchas and Edge Cases

### 1. Case Sensitivity

Condition string comparisons are **case-insensitive** (Java: `StringUtils.equalsIgnoreCase`).

```xml
<!-- These are equivalent -->
<m_Value>cart</m_Value>
<m_Value>Cart</m_Value>
<m_Value>CART</m_Value>
```

### 2. m_Value vs m_StringValue

Both work, but `m_Value` is the modern format:

```xml
<!-- Modern (preferred) -->
<m_Value>cart</m_Value>

<!-- Legacy (still works) -->
<m_StringValue>cart</m_StringValue>
```

### 3. Missing Transitions

If a transition doesn't exist, the state machine may get stuck or use a default fallback. Always define transitions to all related states.

### 4. Priority Conflicts

If two nodes have the same priority and both conditions match, behavior may be unpredictable. Use distinct priorities.

### 5. Bone Weight Defaults

If you don't specify `m_SubStateBoneWeights`, defaults are applied (Spine1, Neck, BackPack, Prop1, Prop2). This may not be what you want for masking.

### 6. Event Sorting

Events are automatically sorted by `timePc`. You don't need to declare them in order.

### 7. Blend Space Edge Cases

If the current (X, Y) is outside all triangles, the engine extrapolates from the nearest edge. This can cause unexpected animation blending at extreme values.

### 8. Infinite Float Values

When `Float.POSITIVE_INFINITY` is used (default for blend times), the system uses fallback values. Explicitly set values to avoid surprises.

---

## Quick Reference Tables

### Condition Types

| Type | Comparison | Example |
|------|------------|---------|
| `STRING` | Equals (case-insensitive) | `Weapon == "cart"` |
| `STRNEQ` | Not equals | `Weapon != "handgun"` |
| `BOOL` | Boolean equals | `isMoving == true` |
| `EQU` | Float equals | `WalkSpeed == 1.0` |
| `NEQ` | Float not equals | `WalkSpeed != 0.0` |
| `LESS` | Float less than | `WalkSpeed < 0.5` |
| `GTR` | Float greater than | `WalkSpeed > 0.5` |
| `ABSLESS` | Absolute value less | `abs(strafe) < 0.3` |
| `ABSGTR` | Absolute value greater | `abs(strafe) > 0.7` |
| `OR` | Logical separator | (groups conditions) |

### Blend Time Guidelines

| Transition | Blend Time | Feel |
|------------|------------|------|
| 0.03s | Very fast | Snappy, responsive |
| 0.05s | Fast | Quick but smooth |
| 0.1s | Medium | Natural, comfortable |
| 0.2s | Slow | Deliberate |
| 0.5s | Very slow | Heavy, momentum |

### Footstep Timing

| Speed | First Step | Second Step | Sound Type |
|-------|------------|-------------|------------|
| Walk | 15-20% | 60-65% | `walk` |
| Run | 15% | 60% | `run` |
| Sprint | 15% | 60% | `sprint` |

### Root Motion (deferredBoneAxis)

| XML Setting | Bone Axis Read | Forward Direction | Use Case |
|-------------|----------------|-------------------|----------|
| `<m_deferredBoneAxis>Y</m_deferredBoneAxis>` | `(x, -z)` | **-Z** is forward | Vanilla PZ animations, -Z forward exports |
| `<m_deferredBoneAxis>Z</m_deferredBoneAxis>` | `(x, y)` | **Y** is forward | Blender Y-forward exports (SaucedCarts) |

**Key files** (Java source references):
- `AnimNode.java:56-65` - Default settings (Translation_Data bone, BoneAxis.Y)
- `AnimationTrack.java:324-329` - Axis to movement conversion
- `IsoGameCharacter.java:1629` - Movement application via `MoveUnmodded()`

---

*Last updated: SaucedCarts v1.0.0 | Build 42.13.1+ | Based on decompiled Java source analysis*