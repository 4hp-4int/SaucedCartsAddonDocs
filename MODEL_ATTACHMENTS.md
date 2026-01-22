# Model Attachment System Reference

This document covers how PZ's model attachment system works based on decompiled source analysis.

## Key Files Analyzed

| File | Purpose |
|------|---------|
| `ModelScript.java` | Parses model definitions from `models_*.txt` scripts |
| `ModelAttachment.java` | Stores offset/rotate/scale for each attachment |
| `ModelManager.java` | Handles attaching items to character bones |
| `Item.java` | Parses item scripts including `ReplaceInPrimaryHand` |
| `ModelInstanceRenderData.java` | Applies attachment transforms during rendering |

---

## How Model Attachments Work

### Attachment Definition (models_*.txt)

```
model ShoppingCartModel
{
    mesh = weapons/2handed/ShoppingCart_PZ|ShoppingCart,
    texture = weapons/2handed/ShoppingCart_Atlas,
    scale = 1.00,

    attachment Bip01_Prop1
    {
        offset = X Y Z,
        rotate = RX RY RZ,
        scale = 1.0,
    }
}
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `offset` | Vector3f | Translation in model units (X Y Z) |
| `rotate` | Vector3f | Rotation in **degrees** (converts to radians internally) |
| `scale` | float | Scale multiplier (default: 1.0) |
| `bone` | string | Optional bone to attach to (for skinned models) |

### Transform Application Order

From `ModelInstanceRenderData.java` lines 108-110:
```java
attachmentXfrm.translation(attachment.getOffset());
Vector3f rotate = attachment.getRotate();
attachmentXfrm.rotateXYZ(rotate.x * PI/180, rotate.y * PI/180, rotate.z * PI/180);
```

1. **Translation** applied first (offset)
2. **Rotation** applied second (in XYZ order, degrees converted to radians)

---

## Character Hand Bone Names

From `ModelManager.java`:

| Bone Name | Used For | Code Reference |
|-----------|----------|----------------|
| `Bip01_Prop1` | Primary hand (right) | Line 681, 694, 704 |
| `Bip01_Prop2` | Secondary hand (left) | Line 688, 699, 709 |

When an item is equipped:
- Primary hand item → attaches to `Bip01_Prop1`
- Secondary hand item → attaches to `Bip01_Prop2`

---

## Item Script Properties

### ReplaceInPrimaryHand / ReplaceInSecondHand

Format: `ReplaceInPrimaryHand = ModelName maskVariableValue,`

Example:
```
ReplaceInPrimaryHand = ShoppingCartModel holdingcartright,
ReplaceInSecondHand = ShoppingCartModel holdingcartleft,
```

Parsed in `Item.java` (lines 1912-1929):
```java
// ReplaceInPrimaryHand = "ShoppingCartModel holdingcartright"
String[] ss = replaceInPrimaryHand.split("\\s+");
replacePrimaryHand.clothingItemName = ss[0];    // "ShoppingCartModel"
replacePrimaryHand.maskVariableValue = ss[1];   // "holdingcartright"
replacePrimaryHand.maskVariableName = "RightHandMask";
```

### What Each Part Does

| Part | Value | Purpose |
|------|-------|---------|
| `clothingItemName` | "ShoppingCartModel" | Either a clothingItem XML name OR model script name |
| `maskVariableValue` | "holdingcartright" | Value for animation variable `RightHandMask` |
| `maskVariableName` | "RightHandMask" | Animation variable to set (auto-assigned) |

### Attachment Resolution (ModelManager.java lines 793-797)

```java
if (!StringUtils.isNullOrEmpty(animMaskAttachment)) {
    // Use custom attachment name from primaryAnimMaskAttachment
    result = addStaticForcedTex(slot.model, staticModel, animMaskAttachment, animMaskAttachment, tex);
} else {
    // Use bone name (Bip01_Prop1 or Bip01_Prop2)
    result = addStaticForcedTex(slot, staticModel, bone, tex);
}
```

**For static models without clothingItem XML:**
- The model's `Bip01_Prop1` attachment is used for primary hand
- The model's `Bip01_Prop2` attachment is used for secondary hand
- `holdingcartright`/`holdingcartleft` are animation mask values, NOT attachment names

---

## Correct Model Script Structure for Two-Handed Items

```
model ShoppingCartModel
{
    mesh = weapons/2handed/ShoppingCart_PZ|ShoppingCart,
    texture = weapons/2handed/ShoppingCart_Atlas,
    scale = 1.00,
    invertX = true,

    /* World placement (when on ground) */
    attachment world
    {
        offset = 0.0 0.0 0.0,
        rotate = 0.0 0.0 0.0,
    }

    /* Primary hand (right) - attaches to Bip01_Prop1 bone */
    attachment Bip01_Prop1
    {
        offset = 0.0 0.0 0.0,
        rotate = 0.0 0.0 0.0,
        scale = 1.0,
    }

    /* Secondary hand (left) - attaches to Bip01_Prop2 bone */
    attachment Bip01_Prop2
    {
        offset = 0.0 0.0 0.0,
        rotate = 0.0 0.0 0.0,
        scale = 1.0,
    }
}
```

---

## Animation Masking Variables

The `maskVariableValue` controls which animation mask plays on the arm:

| Variable | Controls |
|----------|----------|
| `RightHandMask` | Right arm animation masking |
| `LeftHandMask` | Left arm animation masking |

These look for AnimSets in:
- `media/AnimSets/player/maskingright/` for RightHandMask
- `media/AnimSets/player/maskingleft/` for LeftHandMask

Example: `RightHandMask = "holdingcartright"` looks for:
- `media/AnimSets/player/maskingright/holdingcartright.xml`

---

## Coordinate System

Based on vanilla weapon models:

| Axis | Direction | Typical Range |
|------|-----------|---------------|
| X | Left/Right | -0.05 to 0.05 |
| Y | Up/Down (height) | 0.0 to 0.3 |
| Z | Forward/Back | -0.05 to 0.05 |

Rotation (degrees):
| Axis | Rotation |
|------|----------|
| X | Pitch (tilt forward/back) |
| Y | Yaw (rotate left/right) |
| Z | Roll (twist) |

---

## Vanilla Reference Values

From `models_weapons.txt`:

### BaseballBat (2-handed)
```
attachment world { offset = -0.0278 0.245 0.0, rotate = 0.0 0.0 0.0 }
attachment Bip01_Prop2 { offset = -0.0067 -0.0091 -0.0022, rotate = 0.0 0.0 0.0 }
```

### Guitar (2-handed)
```
attachment world { offset = -0.0009 0.2764 -0.0668, rotate = 0.0 -90.0 0.0 }
attachment Bip01_Prop2 { offset = -0.0269 -0.0002 -0.0002, rotate = 180.0 -88.6887 180.0 }
```

### Sledgehammer (2-handed)
```
attachment world { offset = -0.049 0.137 -0.049, rotate = 0.0 -45.0 0.0 }
attachment Bip01_Prop2 { offset = -0.0131 0.0078 0.0007, rotate = 180.0 -11.9336 180.0 }
```

---

## Summary

1. **Attachment names** should be `Bip01_Prop1` (primary/right) and `Bip01_Prop2` (secondary/left)
2. **`holdingcartright`/`holdingcartleft`** are animation mask variable values, NOT attachment names
3. **Offset** is in model units, **rotate** is in degrees
4. Transform order: translation first, then rotation (XYZ)
5. Vanilla 2-handed items typically only define `Bip01_Prop2` attachment (secondary hand)
