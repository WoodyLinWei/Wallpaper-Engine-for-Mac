# Scripted Origin Motion Design

## Goal

Render common Wallpaper Engine `origin` property scripts without executing arbitrary Workshop JavaScript. The first verified fixture is MapleStory: Toy Tower, whose clouds use wrapped horizontal movement and whose elephant airships combine piecewise horizontal movement, vertical bobbing, and randomized restart height.

## Safety boundary

The app will parse only a small, declarative subset of scripts that directly update `value.x` or `value.y`. Unknown syntax remains inert. Wallpaper names, object names, IDs, and asset paths are never used to choose behavior.

Scene-level static assignments such as `shared.speed = 1` are read as numeric constants. No JavaScriptCore context, file access, network access, function calls, or arbitrary expressions are executed.

## Runtime model

`ScriptedOriginMotionParser` converts recognized source into a configuration:

- horizontal per-tick velocity multiplied by the shared scene speed;
- optional alternate velocity while beyond a boundary;
- wrap boundary and restart X;
- optional vertical step, amplitude measured from a center Y, and direction reversal;
- optional random Y range when wrapping.

`ScriptedOriginMotionController` advances the configuration with a fixed 30 Hz accumulator. This preserves the wallpaper author's per-update values while making playback independent of the App's selected display FPS.

`SceneScriptConstantsParser` reads static numeric `shared.<name>` assignments from scene object scripts. The view model builds this context before binding image nodes, then binds every recognized scripted origin through `WESpriteScene`.

## Failure behavior

Malformed, unsupported, non-finite, or incomplete scripts return no configuration and preserve the existing static rendering. Large frame gaps are capped consistently with the existing SpriteKit runtime. Random values are injectable in tests.

## Verification

Unit tests cover Toy Tower cloud and elephant script shapes, shared speed parsing, fixed-step motion, boundary speed, bobbing reversal, wrap/random reset, and unsupported-script rejection. The existing complete scene runtime suite and Universal Release build must also pass.
