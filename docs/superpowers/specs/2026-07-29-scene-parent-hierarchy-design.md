# Wallpaper Engine Scene Parent Hierarchy Design

Date: 2026-07-29

## Goal

Render Wallpaper Engine scene objects with their authored `parent` relationships
instead of treating every object origin as a canvas-space coordinate. This must
restore the complete Happyville houses and provide reusable behavior for other
Workshop scene wallpapers that use the same hierarchy model.

## Scope

- Decode the optional integer `parent` field on scene objects.
- Support parent relationships for every renderable image and particle node.
- Preserve each child's authored local position, scale, rotation, opacity, and
  runtime bindings.
- Inherit later parent movement and transforms through SpriteKit's node tree.
- Preserve source object order as an accumulated scene-wide Z order.
- Fall back safely when a parent is missing, non-renderable, duplicated, or
  involved in a cycle.

This change will not execute arbitrary Workshop JavaScript or implement effect
shaders unrelated to hierarchy.

## Architecture

### Scene model

`WESceneObject` gains `parent: Int?`, decoded and encoded alongside `id`.

### Pure hierarchy resolver

A small Foundation-only resolver accepts records containing:

- stable object ID,
- source index,
- optional parent ID.

It returns a validated attachment for each node:

- root attachment when there is no usable parent;
- parent attachment when the referenced renderable node exists and does not
  create a cycle.

It also calculates local Z as:

- source index for root nodes;
- child source index minus parent source index for child nodes.

The accumulated SpriteKit Z therefore remains equal to the object's original
scene index, including nested descendants.

### Scene construction

`SceneWallpaperViewModel` changes from immediate one-pass attachment to two
phases:

1. Build all renderable nodes and their runtime controllers in source order,
   retaining node, object ID, parent ID, and source index.
2. Resolve the hierarchy, then attach each node either to its validated parent
   or to the scene root.

An object's existing origin remains unchanged. It is interpreted as canvas
space only for root nodes and local parent space for child nodes. Because
children are real SpriteKit descendants, parent motion, scale, and rotation are
inherited automatically.

Runtime bindings continue to hold the actual node. Timed animation,
`MotionItem`, `Mob`, scrolling, and particles remain independent of where the
node is attached.

## Error Handling

- Missing or non-renderable parent: attach the child to the scene root and log
  the reason.
- Duplicate object ID: keep the first renderable node as the parent target and
  log the duplicate.
- Self-parenting or longer cycle: reject the offending parent link, attach that
  node to the root, and log the cycle.
- Objects without `parent`: retain current rendering behavior.

No malformed hierarchy may prevent the rest of the wallpaper from loading.

## Verification

Tests are written before implementation and must demonstrate the original
failure.

Automated coverage:

- `WESceneObject` decodes and re-encodes `parent`.
- A child resolves to its parent even when the parent appears later.
- Nested descendants retain scene-wide accumulated Z order.
- Missing parents, duplicate IDs, self-parenting, and cycles fall back safely.
- The real Happyville package exposes the authored house parent links.
- Resolving Happyville house 3 places its roof at the parent's position plus
  the roof's local offset instead of near the canvas origin.
- Existing Henesys movement, scroll, audio, and animation tests remain green.
- Universal `arm64 + x86_64` Release build succeeds.

Manual coverage:

- Install only on the current Mac.
- Compare Happyville against its packaged preview: all three houses have their
  upper and lower component layers.
- Confirm Santa sleigh motion and audio still work.
- If multiple displays are connected, confirm the same wallpaper still shares
  one audio session.

ZIP artifacts and GitHub remain unchanged until the user approves the complete
local test result.
