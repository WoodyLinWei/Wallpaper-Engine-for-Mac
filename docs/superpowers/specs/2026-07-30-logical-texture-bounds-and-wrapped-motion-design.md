# Logical Texture Bounds and Wrapped Motion Design

## Goal

Restore Wallpaper Engine scene alignment when a static TEX stores logical image content inside a larger backing atlas, and complete safe wrapped horizontal motion for scripts used by Lith Harbor's cloud layers.

The implementation must remain wallpaper-independent. It must not match wallpaper titles, object names, IDs, or asset paths, and it must not alter authored object coordinates.

## Confirmed root causes

Lith Harbor's scene objects use correct center alignment, origins, dimensions, and animation frame sizes. Five static textures have a logical image size smaller than their storage atlas:

- `1920×1080` content in a `2048×2048` atlas;
- `592×505` content in a `1024×512` atlas;
- `3200×1540` content in a `4096×2048` atlas;
- two `2000×157` contents in `2048×256` atlases.

The current renderer uses the complete storage atlas for static textures and scales it to the logical scene-object size. Transparent storage padding is therefore included in the scaling, compressing and shifting background geometry relative to correctly positioned characters.

Lith Harbor also contains sixteen direct origin scripts. The current safe parser recognizes only the eight scripts with explicit numeric multipliers and recognizes none of their `<=` wrap conditions. Scripts using `value.x -= shared.speed` remain static, while recognized layers move without restarting.

## Texture architecture

`TEXMetadata` will expose a normalized logical content rectangle:

- X begins at the left atlas edge.
- Wallpaper Engine image rows begin at the top, so SpriteKit Y begins at `1 - logicalHeight / storageHeight`.
- Width and height are the logical dimensions divided by storage dimensions.
- Invalid, zero, non-finite, or oversized logical dimensions fall back to the complete texture rectangle.

`SceneWallpaperViewModel.buildImageNode` will use this rectangle when a decoded TEX has no animation frames. Animated TEX continues using each `WETextureFrame.normalizedRect`, preserving existing animation behavior.

The SpriteKit node size remains the authored scene object size. Only the sampled texture region changes. This restores one logical image pixel to one authored scene-image pixel without changing origins, scales, hierarchy, or scene aspect-fill behavior.

## Motion parser architecture

`ScriptedOriginMotionParser` will extend the existing safe declarative subset:

- `value.x += shared.speed` and `value.x -= shared.speed` imply a numeric multiplier of `1`;
- existing explicit forms such as `shared.speed * 1.2` remain supported;
- wrap comparisons accept `<`, `<=`, `>`, and `>=`;
- comparison inclusivity is retained in `ScriptedOriginWrapBoundary`;
- restart assignments remain restricted to numeric literals;
- arbitrary JavaScript is never executed.

The existing fixed 30 Hz controller will evaluate inclusive and exclusive boundaries exactly as authored. Unsupported syntax remains inert.

## Data flow

1. `TEXParser` decodes storage and logical dimensions.
2. Static textures receive the validated normalized logical rectangle.
3. SpriteKit renders the cropped region at the authored object size and origin.
4. Scene-level numeric constants are collected as before.
5. Every origin script is passed through the safe parser.
6. Recognized cloud motion advances at the existing fixed source time base and restarts at its authored boundary.

## Failure behavior

- Invalid logical dimensions use the full atlas instead of producing an empty or out-of-range texture.
- Missing shared constants cause the motion script to remain unsupported.
- Malformed comparisons or non-numeric restart positions remain inert.
- Existing Mob, MotionItem, hierarchy, audio, animation, and scroll behavior is unchanged.

## Verification

Automated tests must first fail against current behavior, then cover:

- top-left logical TEX crop math for padded atlases;
- full-rectangle behavior when logical and storage dimensions match;
- safe fallback for invalid bounds;
- implicit `shared.speed` multiplier of one;
- inclusive `<=` and `>=` wrap semantics;
- unchanged explicit multiplier and exclusive-boundary behavior;
- the real Lith Harbor fixture discovering five padded static textures;
- all sixteen Lith Harbor cloud scripts being recognized with wrap boundaries;
- real Henesys, Happyville, Toy Tower, and Lith Harbor fixture regression.

A Universal `arm64 x86_64` Release build must succeed. The installed app must have a valid ad-hoc signature. Visual verification must compare two Lith Harbor screenshots and confirm correctly aligned characters/background plus changing cloud positions.

No ZIP package or GitHub push is part of this change.
