# Logical Texture Bounds and Wrapped Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore scene-to-character alignment for padded static TEX assets and support all Lith Harbor wrapped cloud scripts.

**Architecture:** `TEXMetadata` owns validated logical-to-storage crop math, while `SceneWallpaperViewModel` applies that rectangle only to static textures. The existing safe origin-motion parser gains implicit shared-speed factors and inclusive comparison cases without executing JavaScript.

**Tech Stack:** Swift 5, SpriteKit, Foundation regular expressions, existing command-line scene runtime tests, Xcode Universal Release build.

## Global Constraints

- Never match wallpaper titles, object names, IDs, or asset paths in production behavior.
- Never alter authored object origins, scales, hierarchy, or aspect-fill behavior.
- Never execute Workshop JavaScript.
- Preserve Mob, MotionItem, audio, timed animation, hierarchy, and scroll behavior.
- Do not package a ZIP or push GitHub.

---

### Task 1: Crop static TEX to logical content bounds

**Files:**
- Modify: `Open Wallpaper Engine/Services/SceneParsers/TEXParser.swift`
- Modify: `Open Wallpaper Engine/Services/SceneWallpaperViewModel.swift`
- Modify: `Tests/SceneRuntimeTests/main.swift`

**Interfaces:**
- Produces: `TEXMetadata.normalizedContentRect: CGRect`
- Consumes: `TEXMetadata.width`, `height`, `textureWidth`, and `textureHeight`

- [ ] **Step 1: Write failing crop tests**

Add assertions equivalent to:

```swift
let padded = TEXMetadata(
    format: 0, flags: 0,
    width: 1920, height: 1080,
    textureWidth: 2048, textureHeight: 2048
)
expectEqual(
    padded.normalizedContentRect,
    CGRect(x: 0, y: 0.47265625, width: 0.9375, height: 0.52734375),
    "static TEX samples only its top-left logical content"
)
```

Also assert a matching logical/storage size returns `(0, 0, 1, 1)` and zero or oversized logical dimensions return the full rectangle.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
scripts/test-scene-runtime.sh
```

Expected: compilation fails because `normalizedContentRect` does not exist.

- [ ] **Step 3: Implement validated crop math**

Add:

```swift
var normalizedContentRect: CGRect {
    guard
        width > 0, height > 0,
        textureWidth > 0, textureHeight > 0,
        width <= textureWidth, height <= textureHeight
    else {
        return CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    let normalizedWidth = Double(width) / Double(textureWidth)
    let normalizedHeight = Double(height) / Double(textureHeight)
    return CGRect(
        x: 0,
        y: 1 - normalizedHeight,
        width: normalizedWidth,
        height: normalizedHeight
    )
}
```

In `buildImageNode`, use `SKTexture(rect: decoded.metadata.normalizedContentRect, in: atlasTexture)` when `decoded.frames.isEmpty`; keep animated frame cropping unchanged.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
scripts/test-scene-runtime.sh
```

Expected: `All scene runtime tests passed.`

- [ ] **Step 5: Commit**

```bash
git add 'Open Wallpaper Engine/Services/SceneParsers/TEXParser.swift' \
  'Open Wallpaper Engine/Services/SceneWallpaperViewModel.swift' \
  Tests/SceneRuntimeTests/main.swift
git commit -m 'fix: crop static textures to logical bounds'
```

### Task 2: Complete safe wrapped cloud syntax

**Files:**
- Modify: `Open Wallpaper Engine/Services/SceneRuntime/ScriptedOriginMotionBehavior.swift`
- Modify: `Tests/SceneRuntimeTests/main.swift`

**Interfaces:**
- Extends: `ScriptedOriginWrapBoundary`
- Preserves: `ScriptedOriginMotionParser.parse(_:constants:)`
- Preserves: `ScriptedOriginMotionController.update(deltaTime:)`

- [ ] **Step 1: Write failing motion tests**

Use a script containing:

```javascript
value.x -= shared.speed;
if (value.x <= -200) {
    value.x = 2125;
}
```

Assert `horizontalStep == -0.5`, boundary is inclusive at `-200`, restart X is `2125`, and a controller starting at `-199.5` restarts after one 30 Hz step. Add the symmetric `>=` parser assertion.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
scripts/test-scene-runtime.sh
```

Expected: parser returns `nil` or fails to expose inclusive boundary cases.

- [ ] **Step 3: Implement minimal parser/controller support**

Change the horizontal expression grammar so `shared.<constant>` may omit `* number`, using factor `1` when omitted. Extend comparison capture to `[<>]=?`, map `<=` and `>=` to dedicated enum cases, and evaluate all four cases in `hasCrossedWrapBoundary`.

- [ ] **Step 4: Add and run the real Lith Harbor fixture**

Under `WE_LITH_HARBOR_WALLPAPER`, decode the real scene and assert:

```swift
expectEqual(constants["speed"], 0.5, "Lith Harbor shared speed")
expectEqual(configurations.count, 16, "all Lith Harbor cloud scripts are recognized")
expect(configurations.allSatisfy { $0.wrapBoundary != nil }, "all clouds wrap")
expectEqual(paddedStaticTextureCount, 5, "all padded static textures are detected")
```

Run all four fixtures:

```bash
WE_MAPLE_WALLPAPER='/Users/woody/Documents/Open Wallpaper Engine/3011747820' \
WE_HAPPYVILLE_WALLPAPER='/Users/woody/Documents/Open Wallpaper Engine/3121564310' \
WE_TOY_TOWER_WALLPAPER='/Users/woody/Documents/Open Wallpaper Engine/3000034175' \
WE_LITH_HARBOR_WALLPAPER='/Users/woody/Documents/Open Wallpaper Engine/2982198203' \
scripts/test-scene-runtime.sh
```

Expected: `All scene runtime tests passed.`

- [ ] **Step 5: Build Universal Release**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project 'Open Wallpaper Engine.xcodeproj' \
  -scheme 'Open Wallpaper Engine' -configuration Release \
  -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **` and `lipo -archs` reports `x86_64 arm64`.

- [ ] **Step 6: Commit**

```bash
git add 'Open Wallpaper Engine/Services/SceneRuntime/ScriptedOriginMotionBehavior.swift' \
  Tests/SceneRuntimeTests/main.swift
git commit -m 'fix: support inclusive wrapped scene motion'
```

- [ ] **Step 7: Install and visually verify**

Ad-hoc sign the build, preserve the current `/Applications/Open Wallpaper Engine.app` under `/private/tmp`, install the new app, launch it, and compare two Lith Harbor screenshots. Verify background geometry aligns with character origins and cloud positions change.
