# MapleStory Scene Runtime Implementation Plan

> **For Codex:** Execute this plan sequentially with red-green-refactor testing.
> Do not install over `/Applications/Open Wallpaper Engine.app` until all unit,
> integration, and release-build checks pass.

**Goal:** Make Wallpaper Engine scene `3011747820` render at the correct scale,
animate independently roaming monsters, scroll clouds, and loop its packaged
music on macOS without executing arbitrary Workshop JavaScript.

**Architecture:** Extend the existing package/model/texture pipeline with
script-backed values, a correct TEXV/TEXS parser, a native Mob script adapter,
and a SpriteKit scene runtime. AVFoundation will play packaged audio data. The
existing SwiftUI view model remains the lifecycle owner.

**Tech Stack:** Swift 5 language mode, AppKit, SpriteKit, AVFoundation,
Compression.framework, XCTest-style command-line assertions, Xcode 26.6.

**Target fixture facts already verified:**

- `scene.pkg`: PKGV0018, 68 entries.
- `scene.json`: 58 objects, 1920×1080.
- Audio: `sounds/CavaBien.mp3`, 1,280,000 bytes.
- Animated textures: RGBA8888, LZ4-compressed, TEXS0003 frame metadata.
- Example `materials/lwn.1.tex`: 88×68 atlas, four 44×34 frames.
- Baseline Xcode command completes with `** BUILD SUCCEEDED **`.

---

## Task 1: Add a repeatable scene-runtime test harness

**Files:**

- Create: `Tests/SceneRuntimeTests/main.swift`
- Create: `scripts/test-scene-runtime.sh`

**Step 1: Write a passing harness smoke test**

Create a minimal test runner with named assertions. Its first assertion should
exercise the existing `"1 2 3".parseVector3()` helper so the harness proves it
can compile and execute production code before feature tests are added.

**Step 2: Run it and verify GREEN**

Run:

```bash
./scripts/test-scene-runtime.sh
```

Expected: the smoke assertion passes.

**Step 3: Add only enough source selection to keep the test command stable**

The script must:

- Set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Use a module cache below `/private/tmp`.
- Compile only the scene parser/runtime production files plus the test main.
- Emit the test executable below `/private/tmp`.
- Execute the test binary.

Do not add feature behavior in this step.

**Step 4: Commit**

```bash
git add Tests/SceneRuntimeTests/main.swift scripts/test-scene-runtime.sh
git commit -m "test: add scene runtime harness"
```

---

## Task 2: Preserve plain and script-backed scene values

**Files:**

- Modify: `Open Wallpaper Engine/Services/SceneParsers/SceneModels.swift`
- Modify: `Tests/SceneRuntimeTests/main.swift`

**Step 1: Write failing decoding tests**

Add fixtures for:

1. Plain origin: `"960 540 0"`.
2. Script-backed origin:

   ```json
   {
     "value": "1000 673 0",
     "script": "mob = new shared.Mob({...})"
   }
   ```

3. Plain and script-backed `visible`, `scale`, and `alpha`.
4. Scene sound object containing `["sounds/CavaBien.mp3"]`.
5. Scroll effect containing `speedx`, `speedy`, and `repeat`.

Assertions must prove both `value` and `script` survive decoding.

**Step 2: Run and verify RED**

Run `./scripts/test-scene-runtime.sh`.

Expected: new fixture assertions do not compile or fail because existing models
discard wrapper objects, sound, and effects.

**Step 3: Implement flexible models**

Add:

- `WEScriptedValue<T>` generic decoder for plain or `{value, script}` forms.
- Convenience accessors on `WESceneObject` retaining current call sites.
- Sound fields.
- Effect/pass/constant-shader-value models needed for scroll and opacity.
- Material combo decoding for `SPRITESHEET`.

Keep decoding permissive so unknown Wallpaper Engine fields remain ignored.

**Step 4: Run and verify GREEN**

Run `./scripts/test-scene-runtime.sh`.

Expected: all decoding tests pass.

**Step 5: Commit**

```bash
git add "Open Wallpaper Engine/Services/SceneParsers/SceneModels.swift" Tests/SceneRuntimeTests/main.swift
git commit -m "feat: preserve scripted scene values and effects"
```

---

## Task 3: Parse and decode TEXV spritesheet textures

**Files:**

- Modify: `Open Wallpaper Engine/Services/SceneParsers/TEXParser.swift`
- Modify: `Tests/SceneRuntimeTests/main.swift`

**Step 1: Write failing TEX tests**

Build a small synthetic TEXV0005/TEXI0001/TEXB0003/TEXS0003 fixture in memory.
Use Compression.framework to LZ4-compress a known 2×1 RGBA pixel atlas.

Assert:

- Correct texture/real dimensions.
- Correct format and flags.
- LZ4 output byte count.
- Correct RGBA pixel values.
- Correct frame count, rectangles, and timing.
- Truncated containers and unsupported formats return a typed error.

**Step 2: Run and verify RED**

Run `./scripts/test-scene-runtime.sh`.

Expected: tests fail because the current parser scans for embedded PNG/JPEG and
does not parse LZ4 RGBA or TEXS metadata.

**Step 3: Implement the binary reader and texture result**

Replace the heuristic section scan with bounded sequential parsing:

- Validate `TEXV0005`, `TEXI0001`, and supported TEXB versions.
- Parse format, flags, texture dimensions, real dimensions, images, and mipmaps.
- Decode LZ4 raw blocks using `compression_decode_buffer`.
- Build a `WEDecodedTexture` containing an atlas `NSImage` plus frame metadata.
- Convert RGBA8888 data into a `CGImage` without channel swapping.
- Parse TEXS0001/0002/0003 frames.
- Preserve the old embedded PNG/JPEG path for static textures.
- Report unsupported DXT/BC formats without crashing.

Only the highest-resolution mipmap is needed for Phase A.

**Step 4: Run and verify GREEN**

Run `./scripts/test-scene-runtime.sh`.

Expected: synthetic TEX tests pass.

**Step 5: Run the real wallpaper integration probe**

Pass the target package path to the test runner:

```bash
WE_MAPLE_WALLPAPER="/Users/woody/Documents/Open Wallpaper Engine/3011747820" \
  ./scripts/test-scene-runtime.sh
```

Expected:

- Package title matches the target title.
- `materials/lwn.1.tex` decodes to 88×68.
- Four 44×34 frames are discovered.
- `sounds/CavaBien.mp3` exists.

**Step 6: Commit**

```bash
git add "Open Wallpaper Engine/Services/SceneParsers/TEXParser.swift" Tests/SceneRuntimeTests/main.swift
git commit -m "feat: decode Wallpaper Engine TEX spritesheets"
```

---

## Task 4: Parse Mob scripts and implement deterministic behavior

**Files:**

- Create: `Open Wallpaper Engine/Services/SceneRuntime/MobBehavior.swift`
- Modify: `Tests/SceneRuntimeTests/main.swift`
- Modify: `Open Wallpaper Engine.xcodeproj/project.pbxproj`

**Step 1: Write failing parser tests**

Use representative scripts from the target package and assert extraction of:

- `[132, 1786]`, move list, stand list, speed `1.0`.
- `[400, 1515]`, speed `2.2`.
- `[480, 1440]`, flower-mushroom frame lists, speed `2.5`.
- A malformed/non-Mob script returns `nil`.

The parser must tolerate whitespace, integer/decimal frame values, comments, and
trailing commas.

**Step 2: Write failing state-machine tests**

Inject a sequence-based random source. Assert:

- Initial X is inside range.
- Initial direction is deterministic from the injected values.
- Moving advances X and move frames.
- Standing holds X and advances stand frames.
- Bounds clamp and reverse direction.
- State durations are within 1–4 seconds.
- Two controllers consume independent random sequences.

**Step 3: Run and verify RED**

Run `./scripts/test-scene-runtime.sh`.

Expected: missing parser/controller types.

**Step 4: Implement the smallest native adapter**

Add:

- `MobBehaviorConfiguration`.
- `MobScriptParser`.
- `MobRandomSource` protocol and system/test implementations.
- `MobControllerState`.
- `MobController.update(deltaTime:)`.

Use time-based movement normalized to the script's 60 Hz units so global app FPS
does not change monster speed. Advance script frames at 30 FPS.

Do not execute JavaScript.

**Step 5: Run and verify GREEN**

Run `./scripts/test-scene-runtime.sh`.

Expected: all Mob parser/state tests pass.

**Step 6: Commit**

```bash
git add "Open Wallpaper Engine/Services/SceneRuntime/MobBehavior.swift" \
  "Open Wallpaper Engine.xcodeproj/project.pbxproj" \
  Tests/SceneRuntimeTests/main.swift
git commit -m "feat: add native random mob behavior"
```

---

## Task 5: Integrate animated layers into SpriteKit

**Files:**

- Create: `Open Wallpaper Engine/Services/SceneRuntime/WESpriteScene.swift`
- Modify: `Open Wallpaper Engine/Services/SceneWallpaperViewModel.swift`
- Modify: `Open Wallpaper Engine.xcodeproj/project.pbxproj`
- Modify: `Tests/SceneRuntimeTests/main.swift`

**Step 1: Write failing runtime mapping tests**

Assert:

- A TEXS frame at top-left maps to the correct SpriteKit normalized rectangle.
- Scene object index maps to monotonically increasing `zPosition`.
- Script-backed origin uses its fallback Y and a randomized in-range X.
- Direction maps to horizontal sprite flipping.
- Static images still produce one node.

**Step 2: Run and verify RED**

Run `./scripts/test-scene-runtime.sh`.

Expected: missing runtime types or incorrect mappings.

**Step 3: Implement the SpriteKit runtime**

Add `WESpriteScene`:

- Own animated-node bindings.
- Track `lastUpdateTime`.
- Advance Mob controllers in `update(_:)`.
- Apply node position, frame texture, and horizontal flip.

Refactor `SceneWallpaperViewModel`:

- Decode all visible image layers rather than dropping additive layers.
- Assign deterministic `zPosition` by scene order.
- Load `WEDecodedTexture`, build frame textures from atlas rectangles, and use
  the first frame for static fallback.
- Attach Mob controllers when `origin.script` matches.
- Let non-Mob layers use TEXS frame timing automatically, including butterflies
  and portals.
- Retain the preview fallback only when no image node can be built.

The logical scene coordinate system remains 1920×1080; do not invert Y.

**Step 4: Run and verify GREEN**

Run `./scripts/test-scene-runtime.sh`.

Expected: runtime mapping tests pass.

**Step 5: Build arm64 Debug**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project "Open Wallpaper Engine.xcodeproj" \
  -scheme "Open Wallpaper Engine" -configuration Debug \
  -derivedDataPath /private/tmp/owe-maple-derived \
  -arch arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

**Step 6: Commit**

```bash
git add "Open Wallpaper Engine/Services/SceneRuntime/WESpriteScene.swift" \
  "Open Wallpaper Engine/Services/SceneWallpaperViewModel.swift" \
  "Open Wallpaper Engine.xcodeproj/project.pbxproj" \
  Tests/SceneRuntimeTests/main.swift
git commit -m "feat: render animated Wallpaper Engine scene layers"
```

---

## Task 6: Add cloud scroll and scene audio lifecycle

**Files:**

- Create: `Open Wallpaper Engine/Services/SceneRuntime/SceneAudioController.swift`
- Modify: `Open Wallpaper Engine/Services/SceneWallpaperViewModel.swift`
- Modify: `Open Wallpaper Engine/WallpaperView/SceneWallpaperView.swift`
- Modify: `Open Wallpaper Engine.xcodeproj/project.pbxproj`
- Modify: `Tests/SceneRuntimeTests/main.swift`

**Step 1: Write failing effect/audio discovery tests**

Assert:

- Both target cloud layers decode `speedx = 0.15000001`, `speedy = 0`.
- The scene finds `sounds/CavaBien.mp3`.
- An audio controller state model maps play rate/volume/sleep/wake correctly.
- Missing audio leaves visuals active.

**Step 2: Run and verify RED**

Run `./scripts/test-scene-runtime.sh`.

Expected: missing effect/audio runtime behavior.

**Step 3: Implement cloud scroll**

For recognized `effects/scroll/effect.json` layers:

- Attach a small SpriteKit shader using `u_time`.
- Wrap UV coordinates with `fract`.
- Feed decoded `speedx`, `speedy`, and repeat values.
- Fall back to the unmodified texture if shader setup fails.

**Step 4: Implement audio**

Add `SceneAudioController` using `AVAudioPlayer(data:)`:

- Select the first valid scene sound entry.
- Loop with `numberOfLoops = -1`.
- Observe shared `playRate` and `playVolume`.
- Pause/resume across global pause and display sleep/wake.
- Release the old player when wallpaper changes.

`SceneWallpaperView` must forward the same pause state used by `SKView` to the
view model/audio controller.

**Step 5: Run and verify GREEN**

Run `./scripts/test-scene-runtime.sh`.

Expected: all tests pass.

**Step 6: Build**

Run the arm64 Debug build command from Task 5.

Expected: `** BUILD SUCCEEDED **`.

**Step 7: Commit**

```bash
git add "Open Wallpaper Engine/Services/SceneRuntime/SceneAudioController.swift" \
  "Open Wallpaper Engine/Services/SceneWallpaperViewModel.swift" \
  "Open Wallpaper Engine/WallpaperView/SceneWallpaperView.swift" \
  "Open Wallpaper Engine.xcodeproj/project.pbxproj" \
  Tests/SceneRuntimeTests/main.swift
git commit -m "feat: add scene audio and scrolling effects"
```

---

## Task 7: Add per-wallpaper fit/fill scaling

**Files:**

- Create: `Open Wallpaper Engine/Services/SceneRuntime/SceneScaleMode.swift`
- Modify: `Open Wallpaper Engine/Services/WallpaperViewModel.swift`
- Modify: `Open Wallpaper Engine/WallpaperView/SceneWallpaperView.swift`
- Modify: `Open Wallpaper Engine/ContentView/Components/Alerts/DisplaySettings.swift`
- Modify: `Open Wallpaper Engine.xcodeproj/project.pbxproj`
- Modify: `Tests/SceneRuntimeTests/main.swift`

**Step 1: Complete failing scale tests**

Assert:

- Default is `.fit`.
- `.fit` maps to SpriteKit `.aspectFit`.
- `.fill` maps to `.aspectFill`.
- A per-wallpaper dictionary encodes and decodes both values.

**Step 2: Run and verify RED**

Run `./scripts/test-scene-runtime.sh`.

Expected: missing scale types/store.

**Step 3: Implement persistence and UI**

- Store scale modes keyed by normalized wallpaper directory path.
- Default scene wallpapers to `fit`.
- Apply the value every time a scene is presented or settings change.
- Add a compact Fit/Fill picker to Display Settings only when the selected
  wallpaper type is `scene`.
- Rebuild/update wallpaper windows after selection.

Use localized plain labels already understandable in the current UI; avoid a
broader settings redesign.

**Step 4: Run and verify GREEN**

Run `./scripts/test-scene-runtime.sh`.

Expected: scale tests pass.

**Step 5: Build**

Run the arm64 Debug build command.

Expected: `** BUILD SUCCEEDED **`.

**Step 6: Commit**

```bash
git add "Open Wallpaper Engine/Services/SceneRuntime/SceneScaleMode.swift" \
  "Open Wallpaper Engine/Services/WallpaperViewModel.swift" \
  "Open Wallpaper Engine/WallpaperView/SceneWallpaperView.swift" \
  "Open Wallpaper Engine/ContentView/Components/Alerts/DisplaySettings.swift" \
  "Open Wallpaper Engine.xcodeproj/project.pbxproj" \
  Tests/SceneRuntimeTests/main.swift
git commit -m "feat: add per-wallpaper scene scaling"
```

---

## Task 8: Run target-package integration validation

**Files:**

- Modify: `Tests/SceneRuntimeTests/main.swift`
- Create: `scripts/validate-maple-scene.sh`

**Step 1: Add target-package assertions**

The validation script must accept a wallpaper directory argument and report:

- Project title and scene projection.
- Number of rendered image layers.
- Number of Mob scripts parsed.
- Number of animated textures decoded.
- Count of audio entries.
- Count of scroll effects.
- Unsupported assets/effects.

Assert minimums for this target:

- 57 non-audio scene objects considered.
- More than 20 Mob behaviors.
- At least 10 animated textures.
- One audio track.
- Two scroll layers.

**Step 2: Run validation**

Run:

```bash
./scripts/validate-maple-scene.sh \
  "/Users/woody/Documents/Open Wallpaper Engine/3011747820"
```

Expected: all target minimums pass and the title is exact.

**Step 3: Run all unit tests**

Run `./scripts/test-scene-runtime.sh`.

Expected: all tests pass.

**Step 4: Commit**

```bash
git add Tests/SceneRuntimeTests/main.swift scripts/validate-maple-scene.sh
git commit -m "test: validate MapleStory scene package"
```

---

## Task 9: Release build, install, and visual verification

**Files:**

- Modify only if verification finds a concrete defect.

**Step 1: Release build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project "Open Wallpaper Engine.xcodeproj" \
  -scheme "Open Wallpaper Engine" -configuration Release \
  -derivedDataPath /private/tmp/owe-maple-release \
  -arch arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

**Step 2: Stage and sign**

Copy the built app to a new explicit directory below `/private/tmp`, remove only
extended attributes from that staged copy, and ad-hoc sign with the existing
entitlements.

Verify:

```bash
codesign --verify --deep --strict --verbose=2 \
  "/private/tmp/.../Open Wallpaper Engine.app"
```

Expected: valid on disk.

**Step 3: Install**

After the build, tests, and signature verification pass:

- Quit the currently running Open Wallpaper Engine process.
- Replace only `/Applications/Open Wallpaper Engine.app`.
- Launch the exact installed app path.

This step requires filesystem/GUI approval if the sandbox requests it.

**Step 4: Runtime log verification**

Collect logs for at least 20 seconds and verify:

- Target title `MapleStory: Henesys Hunting Ground I 冒险岛：射手训练场1`.
- `scene.json` loaded with 58 objects.
- Mob adapter count is non-zero and no controller leaves its platform range.
- Animated atlas count includes the target monster textures.
- `CavaBien.mp3` starts and loops.
- No texture-parser crash or repeated decode failure.

**Step 5: Visual verification**

Using the installed app:

- Select target wallpaper `3011747820`.
- Confirm full composition in Fit mode.
- Observe at least two monster types for 20 seconds.
- Confirm independent walk/stand transitions and boundary reversal.
- Confirm butterfly/portal animation.
- Confirm clouds move continuously.
- Confirm music plays, mute works, pause freezes both visuals and audio, and
  resume continues.
- Toggle Fill and return to Fit to verify the position setting.

**Step 6: Final checks**

Run:

```bash
git status --short
git log --oneline -10
```

Report the exact test/build/signature/runtime evidence, remaining unsupported
effects, and Phase B recommendations. Do not claim success without the observed
runtime evidence.
