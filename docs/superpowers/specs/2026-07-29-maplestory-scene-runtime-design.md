# MapleStory Scene Runtime Compatibility Design

Date: 2026-07-29  
Target wallpaper: `3011747820` — `MapleStory: Henesys Hunting Ground I 冒险岛：射手训练场1`

## Context

Open Wallpaper Engine currently renders Wallpaper Engine scene projects as a set of
static SpriteKit nodes. It reads `scene.json`, model JSON, material JSON, and one
texture per material, but it does not preserve script-wrapped values, texture
animation frames, scene audio, or material effects. It also forces
`SKScene.ScaleMode.aspectFill`, which crops a 16:9 scene on narrower displays.

The target wallpaper is a 1920×1080 scene package. Its behavior is defined by:

- `sounds/CavaBien.mp3`, played as looping background music.
- A shared JavaScript `Mob` class that assigns each monster a random starting
  position and direction, alternates between walking and standing for random
  1–4 second periods, changes animation frames, and turns at platform bounds.
- Per-monster scripts containing movement ranges, frame lists, and speed.
- Scrolling cloud materials and several transparency/effect materials.
- A `mob` user property that controls monster density.

The supplied screen recording is only a visual reference. It is not a source
asset and must not be converted into a video wallpaper.

## Goals

### Phase A

Make the target wallpaper behave like its Wallpaper Engine version on macOS:

1. Show the entire scene with correct coordinates and layer order.
2. Animate monster sprites and reproduce their random walking/standing behavior.
3. Reproduce the continuously scrolling cloud layer.
4. Loop `CavaBien.mp3` and respect wallpaper pause/resume lifecycle.
5. Provide a per-wallpaper scale mode so the user can choose complete display
   or edge-to-edge cropping.
6. Implement compatibility using scene contents and script patterns, not a
   hard-coded Workshop ID.

### Phase B

Generalize the Phase A adapters into a broader Wallpaper Engine scene runtime:

- More texture animation layouts.
- More recognized script behaviors.
- More material effects, particles, and user properties.
- Optional JavaScriptCore-based execution after a safe host API is designed.

## Non-goals for Phase A

- Full Wallpaper Engine JavaScript API compatibility.
- Arbitrary JavaScript execution from downloaded Workshop files.
- Pixel-identical rendering of every proprietary shader.
- Conversion of the reference recording into a looping movie.

## Chosen Approach

Add a native, data-driven compatibility layer on top of the existing SpriteKit
renderer.

This approach keeps the application lightweight, integrates with its current
pause/resume lifecycle, and can be expanded incrementally. It avoids embedding a
large external runtime and avoids replacing live randomized behavior with a
fixed video.

The Phase A script adapter will recognize the target wallpaper's declarative
`new shared.Mob({...})` pattern. It will extract ranges, movement frames,
standing frames, speed, and initial placement rules, then execute equivalent
native Swift behavior. The JavaScript source is treated as data and is not
executed.

## Architecture

### Scene package access

`PKGParser` will remain the authoritative package reader and gain small
convenience APIs for:

- Enumerating and extracting raw entries.
- Resolving resource paths consistently.
- Loading audio data into a temporary cache owned by the scene runtime when an
  API requires a file URL.

All package paths must be normalized and must not escape the wallpaper package.

### Flexible scene values

Wallpaper Engine scene fields can be either plain values or objects such as:

```json
{
  "script": "...",
  "value": "960 540 0"
}
```

Introduce a generic script-backed value model that retains:

- The fallback/current value.
- The associated script source.

`origin`, `visible`, `alpha`, and other needed fields will decode through this
model. Existing plain-value wallpapers must continue to decode unchanged.

### Resource and texture animation loading

Add a scene resource loader that resolves the chain:

`scene object → model → material → texture`

It will return a renderable resource containing:

- Base texture.
- All available animation frames or atlas regions.
- Frame duration/sequence metadata when present.
- Material blend information.
- Recognized effect metadata.

`TEXParser` will expose metadata and supported image payloads without changing
the existing static-image behavior. Unsupported compressed formats will produce
diagnostics and fall back safely instead of crashing.

### Mob behavior adapter

Add a `MobScriptParser` that recognizes the following fields from
`new shared.Mob({...})`:

- `range`
- `moveList`
- `standList`
- `speed`
- optional `jumpFrame`

Parsing produces a `MobBehaviorConfiguration`. Invalid or incomplete scripts
return no behavior, leaving the layer static.

Add a `MobController` attached to the sprite node. It will:

1. Randomize initial X position within the configured range.
2. Randomize initial direction.
3. Alternate walking and standing for 1–4 seconds.
4. Advance animation frames at the source wallpaper's intended 30 FPS cadence.
5. Move at the configured speed and reverse at platform bounds.
6. Preserve per-instance independent randomness.
7. Flip the sprite horizontally when direction changes.

Randomness will be injectable in tests so boundary and state transitions are
deterministic.

### Scene runtime

Replace the purely static scene builder with a small runtime:

- `WESpriteScene`: owns animated layer controllers and updates them from
  SpriteKit's frame callback.
- `SceneNodeFactory`: creates correctly positioned and ordered nodes.
- `SceneAudioController`: owns looping scene audio.
- Effect adapters: initially a horizontal texture scroll adapter for the cloud
  material.

The runtime will use Wallpaper Engine's logical 1920×1080 coordinate space.
Scene object order will map deterministically to `zPosition`. Existing
alpha/additive layers will no longer be discarded solely because of blend mode;
unsupported effects will render their base texture where possible.

### Scaling

Introduce:

```swift
enum SceneScaleMode: String, Codable {
    case fit
    case fill
}
```

- `fit` maps to SpriteKit `.aspectFit` and shows the complete 16:9 scene,
  accepting letterboxing on a differently shaped display.
- `fill` maps to `.aspectFill` and fills the display while cropping edges.

Phase A defaults scene wallpapers to `fit`, because losing platform edges also
breaks the visual meaning of the monsters' movement ranges. The setting will be
stored per wallpaper so other wallpapers can use `fill`.

### Audio

`SceneAudioController` will use AVFoundation to:

- Load packaged MP3 data through a runtime-owned temporary file.
- Loop indefinitely.
- Start only when the scene becomes active.
- Pause when the renderer pauses or the display sleeps.
- Resume without restarting from zero.
- Stop and release resources when the wallpaper changes.

If the audio entry is missing or unsupported, the visual scene continues and a
diagnostic is logged.

### Lifecycle

`SceneWallpaperViewModel` remains the owner exposed to SwiftUI. It will:

- Build and publish one scene runtime per selected wallpaper.
- Forward sleep/wake and application playback state to both SpriteKit and audio.
- Tear down the previous runtime before loading another wallpaper.

UI changes will stay minimal: a scene scale selector and audio enable/volume
controls only where scene wallpapers are configured.

## Error Handling

- Malformed package indexes, invalid offsets, and path traversal are rejected.
- Malformed script patterns are logged and rendered statically.
- Missing textures use the existing preview fallback where possible.
- Unsupported shaders render their base layer rather than disappearing.
- Missing audio never prevents scene rendering.
- Runtime errors must identify the scene object/material path in logs.

## Testing Strategy

Because the installed machine does not have the full Xcode application, tests
will be written as Swift source tests runnable with the available Apple command
line Swift toolchain.

Required tests:

1. Flexible plain and script-backed scene value decoding.
2. `MobScriptParser` extraction using real representative scripts from
   wallpaper `3011747820`.
3. Deterministic mob initialization, movement, standing, frame cycling, and
   boundary reversal.
4. Scale-mode mapping.
5. Package entry extraction and rejection of unsafe paths.
6. Audio entry discovery.
7. Regression fixture proving a plain static scene still builds.

After unit tests pass, the app will be compiled, packaged, ad-hoc signed, and
opened against the target wallpaper. Runtime logs and a visual inspection will
verify:

- Full map placement.
- Independent monster motion for at least 20 seconds.
- Animation frame changes.
- Cloud movement.
- Looping music and pause/resume.

## Phase A Acceptance Criteria

- Target title and Workshop package are correctly identified as
  `MapleStory: Henesys Hunting Ground I 冒险岛：射手训练场1` / `3011747820`.
- The complete 1920×1080 composition is visible in `fit` mode.
- At least two monster types animate and independently switch between standing
  and walking.
- Monsters remain inside their script-defined platform ranges.
- `CavaBien.mp3` loops and pauses/resumes with the wallpaper.
- The cloud layer visibly scrolls.
- The app builds successfully, passes the new tests, is installed at
  `/Applications/Open Wallpaper Engine.app`, and launches without a new
  Gatekeeper warning.

## Phase B Entry Criteria

Phase B begins only after Phase A is verified on the target wallpaper. Remaining
unsupported scene constructs will be inventoried from logs and prioritized by
how many downloaded wallpapers they unlock, rather than by one-off hard-coding.
