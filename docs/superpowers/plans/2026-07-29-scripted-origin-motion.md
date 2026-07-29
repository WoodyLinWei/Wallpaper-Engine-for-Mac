# Scripted Origin Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safe, generic movement for Wallpaper Engine origin scripts such as Toy Tower's moving clouds and elephant airships.

**Architecture:** Parse a whitelisted property-script subset into immutable motion configurations, then advance nodes through a deterministic fixed-step controller. Collect static shared numeric constants at scene load and pass them to every parser without executing JavaScript.

**Tech Stack:** Swift 5, Foundation regular expressions, SpriteKit, existing command-line scene runtime tests, Xcode Universal Release build.

## Global Constraints

- Do not execute arbitrary Workshop JavaScript.
- Do not match wallpaper names, object names, IDs, or asset paths.
- Do not package ZIP files or push GitHub.
- Preserve all existing scene runtime behavior.

---

### Task 1: Parse and run common scripted origin motion

**Files:**
- Create: `Open Wallpaper Engine/Services/SceneRuntime/ScriptedOriginMotionBehavior.swift`
- Modify: `Tests/SceneRuntimeTests/main.swift`
- Modify: `scripts/test-scene-runtime.sh`
- Modify: `Open Wallpaper Engine.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `SceneScriptConstantsParser.parse(_:) -> [String: Double]`
- Produces: `ScriptedOriginMotionParser.parse(_:constants:) -> ScriptedOriginMotionConfiguration?`
- Produces: `ScriptedOriginMotionController.update(deltaTime:) -> MotionItemPosition`

- [ ] **Step 1: Write failing parser and controller tests**

Add fixture scripts matching Toy Tower's direct horizontal cloud update and elephant piecewise/bobbing update. Assert parsed velocities, boundaries, wrap coordinates and random range, then assert deterministic fixed-step positions using an injected random source.

- [ ] **Step 2: Run tests and verify RED**

Run: `scripts/test-scene-runtime.sh`

Expected: Swift compilation fails because the new parser and controller types do not exist.

- [ ] **Step 3: Implement the minimal safe parser and controller**

Use anchored regular-expression captures for recognized assignments and conditions. Reject scripts lacking a horizontal update or containing values that cannot be converted to finite `Double`s. Advance once for each accumulated `1 / 30` second and cap incoming delta time at one second.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `scripts/test-scene-runtime.sh`

Expected: `All scene runtime tests passed.`

### Task 2: Bind parsed motion to every scene image

**Files:**
- Modify: `Open Wallpaper Engine/Services/SceneRuntime/WESpriteScene.swift`
- Modify: `Open Wallpaper Engine/Services/SceneWallpaperViewModel.swift`
- Modify: `Tests/SceneRuntimeTests/main.swift`

**Interfaces:**
- Consumes: `ScriptedOriginMotionController`
- Produces: `WESpriteScene.bindScriptedOriginMotion(node:controller:)`

- [ ] **Step 1: Add a failing integration assertion**

Decode the Toy Tower fixture, collect scene constants, and assert that the known cloud and airship origin scripts produce configurations without relying on their IDs or names.

- [ ] **Step 2: Run tests and verify RED**

Run: `scripts/test-scene-runtime.sh`

Expected: fixture assertion fails before the scene binding/context implementation is present.

- [ ] **Step 3: Add scene context and SpriteKit binding**

Collect shared assignments from all object property scripts before node construction. After existing Mob and MotionItem recognition, bind generic scripted origin motion and update its node position from `WESpriteScene.update(_:)`.

- [ ] **Step 4: Run regression tests and Universal build**

Run: `scripts/test-scene-runtime.sh`

Expected: `All scene runtime tests passed.`

Run: `xcodebuild -project 'Open Wallpaper Engine.xcodeproj' -scheme 'Open Wallpaper Engine' -configuration Release -destination 'generic/platform=macOS' ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build`

Expected: `** BUILD SUCCEEDED **`
