# Character Generation Guide

> Documentation for generating pixel art characters using PixelLab MCP.

---

## Successful Character: Player (Turret Platform V3)

**Character ID:** `d53589d1-d44c-4046-b912-d872c89cd9e1`

### Parameters Used

```json
{
  "ai_freedom": 100,
  "detail": "high detail",
  "n_directions": 8,
  "outline": "single color black outline",
  "shading": "medium shading",
  "size": 128,
  "view": "high top-down",
  "proportions": {
    "type": "custom",
    "head_size": 0.5,
    "arms_length": 0.5,
    "legs_length": 0.5,
    "shoulder_width": 1.5,
    "hip_width": 1.2
  }
}
```

### Description Prompt

```
Mobile turret platform with legs, NOT a robot, NOT humanoid. A chunky 
cylindrical pedestal or barrel-shaped base that walks on two stubby peg 
legs. The top is completely flat like a table or platform, with a glowing 
cyan circular socket in the center for mounting weapons, and a thin antenna 
sticking up. NO head, NO face on top, NO eyes on top. On the front side of 
the barrel body there is a small rectangular LED screen displaying a simple 
happy face emoticon. Chrome white metallic drum-shaped body with horizontal 
panel lines. Very short stumpy cylindrical legs at the bottom. Looks like a 
walking ammunition crate or mobile weapon mount. Futuristic sci-fi military 
equipment with cute proportions.
```

### Animations

| Animation | Template | Description |
|-----------|----------|-------------|
| walk | `walking-4-frames` | Waddling forward with short stubby peg legs, slight body tilt and bounce, mechanical stomping walk |
| idle | `breathing-idle` | Gentle breathing idle, slight up and down bob, antenna sways subtly, LED screen blinks occasionally |

---

## Lessons Learned

### Breaking Humanoid Assumptions

When creating non-humanoid characters, the AI tends to add heads/faces. To prevent this:

1. **Reframe the concept** — Use "turret platform", "mobile base", "walking pedestal" instead of "robot"
2. **Explicit negations** — Include "NOT a robot", "NOT humanoid", "NO head", "NO face on top"
3. **Alternative comparisons** — "Like a walking ammunition crate", "barrel-shaped base"
4. **Minimum AI freedom** — Use `ai_freedom: 100` (lowest setting) for strict prompt adherence
5. **Custom proportions** — Set `head_size: 0.5` to minimize any head that might appear

### Proportion Settings

| Parameter | Range | Notes |
|-----------|-------|-------|
| `head_size` | 0.5 - 2.0 | 0.5 = smallest, good for headless designs |
| `arms_length` | 0.5 - 2.0 | 0.5 = no/minimal arms |
| `legs_length` | 0.5 - 2.0 | 0.5 = stubby legs |
| `shoulder_width` | 0.5 - 2.0 | 1.5 = wide barrel body |
| `hip_width` | 0.5 - 2.0 | 1.2 = sturdy base |

### AI Freedom Scale

| Value | Behavior |
|-------|----------|
| 100 | Strict — follows prompt very closely |
| 250 | Conservative — minor creative additions |
| 500 | Balanced — moderate interpretation |
| 750 | Creative — significant artistic freedom |
| 999 | Wild — heavy reinterpretation |

**Recommendation:** Use 100-200 for specific designs, 400-600 for general concepts.

---

## Standard Parameters (Per Style Guide)

All characters should use these baseline settings unless noted:

```json
{
  "view": "high top-down",
  "detail": "high detail",
  "outline": "single color black outline",
  "shading": "medium shading",
  "size": 128,
  "n_directions": 8
}
```

---

## Animation Templates

Common templates for our game:

| Template ID | Frames | Use Case |
|-------------|--------|----------|
| `walking-4-frames` | 4 | Standard walk cycle |
| `walking-6-frames` | 6 | Smoother walk |
| `walking-8-frames` | 8 | Very smooth walk |
| `breathing-idle` | varies | Idle animation |
| `running-4-frames` | 4 | Fast movement |

---

## Failed Attempts (For Reference)

### V1: Too Much Freedom
- `ai_freedom: 600`, described as "robot"
- **Result:** Added a round head on top

### V2: Reduced Freedom
- `ai_freedom: 150`, "NO HEAD" emphasis
- **Result:** Smaller head, but still visible

### V3: Reframed Concept ✓
- `ai_freedom: 100`, "turret platform" not "robot"
- **Result:** Success! Flat-topped cylinder

---

## Character Registry

| Name | ID | Status | Notes |
|------|-----|--------|-------|
| Player (Turret Platform V3) | `d53589d1-d44c-4046-b912-d872c89cd9e1` | ✅ Active | Flat-top, LED face, stubby legs |
| Player Robot V2 Headless | `4682d811-f28f-4858-9768-0122a24c3b8f` | ❌ Rejected | Small head still visible |
| Player Robot V2 | `53ccb9c4-dea7-4519-bbdc-f7f57eaad165` | ❌ Rejected | Had a head |

---

*Last updated: November 2025*
