# Scene Parent Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render Wallpaper Engine scene objects through their authored parent hierarchy so composite houses and similar Workshop assets appear complete and inherit parent transforms.

**Architecture:** Decode `parent` in the scene model, validate relationships with a pure Foundation resolver, then build every renderable SpriteKit node before attaching nodes to their resolved parents. Preserve global scene order by assigning child-local Z offsets whose accumulated value equals the original object index.

**Tech Stack:** Swift 5, Foundation, SpriteKit, the existing PKG/TEX parsers, shell-based scene runtime tests, Xcode Universal macOS Release build.

## Global Constraints

- Do not execute arbitrary Workshop JavaScript.
- Apply hierarchy behavior generically; do not key behavior to Happyville titles, IDs, or asset names.
- Malformed, missing, duplicate, or cyclic parent data must not prevent the wallpaper from loading.
- Existing `Mob`, `MotionItem`, timed animation, scroll, particle, and shared-audio behavior must remain active.
- Install and validate only on the current Mac.
- Do not update ZIP artifacts or push GitHub until the user approves the complete local result.

---

### Task 1: Decode and Validate Scene Hierarchies

**Files:**
- Create: `Open Wallpaper Engine/Services/SceneRuntime/SceneHierarchyResolver.swift`
- Modify: `Open Wallpaper Engine/Services/SceneParsers/SceneModels.swift`
- Modify: `Open Wallpaper Engine.xcodeproj/project.pbxproj`
- Modify: `scripts/test-scene-runtime.sh`
- Test: `Tests/SceneRuntimeTests/main.swift`

**Interfaces:**
- Consumes: `WESceneObject.id: Int?`, `WESceneObject.parent: Int?`, and source array indices.
- Produces: `SceneHierarchyRecord(id: Int?, parentID: Int?, sourceIndex: Int)`, `SceneHierarchyAttachment.parent(sourceIndex: Int, localZ: Double)`, `SceneHierarchyAttachment.root(localZ: Double, reason: SceneHierarchyFallbackReason?)`, and `SceneHierarchyResolver.resolve(_:) -> [SceneHierarchyAttachment]`.

- [ ] **Step 1: Write failing model and resolver tests**

Add tests that decode `{"id":198,"parent":170}`, require round-trip encoding to retain `parent`, resolve a child whose parent occurs later, preserve accumulated Z for a grandchild, and return root fallbacks for missing parents, duplicate IDs, self-parenting, and two-node cycles.

```swift
let records = [
    SceneHierarchyRecord(id: 198, parentID: 170, sourceIndex: 0),
    SceneHierarchyRecord(id: 170, parentID: nil, sourceIndex: 1)
]
expectEqual(
    SceneHierarchyResolver.resolve(records)[0],
    .parent(sourceIndex: 1, localZ: -1),
    "child resolves to a later parent"
)
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
WE_HAPPYVILLE_WALLPAPER='/Users/woody/Documents/Open Wallpaper Engine/3121564310' ./scripts/test-scene-runtime.sh
```

Expected: compilation fails because `parent`, `SceneHierarchyRecord`, and `SceneHierarchyResolver` do not exist.

- [ ] **Step 3: Implement model decoding and pure hierarchy resolution**

Add `parent` to `WESceneObject.CodingKeys`, decoding, and encoding. Implement a resolver that keeps the first source index for each unique renderable ID, follows parent chains with a visited set, rejects missing and cyclic links, and calculates `localZ = child.sourceIndex - parent.sourceIndex`.

```swift
struct SceneHierarchyRecord: Equatable {
    let id: Int?
    let parentID: Int?
    let sourceIndex: Int
}

enum SceneHierarchyAttachment: Equatable {
    case root(localZ: Double, reason: SceneHierarchyFallbackReason?)
    case parent(sourceIndex: Int, localZ: Double)
}
```

- [ ] **Step 4: Register the resolver in the Xcode project and test compiler**

Add `SceneHierarchyResolver.swift` to the SceneRuntime group, Sources build phase, and `scripts/test-scene-runtime.sh`.

- [ ] **Step 5: Run the test and verify GREEN**

Run the command from Step 2.

Expected: all scene runtime tests pass, including hierarchy fallback and real Happyville parent-field assertions.

- [ ] **Step 6: Commit**

```bash
git add 'Open Wallpaper Engine/Services/SceneParsers/SceneModels.swift' \
  'Open Wallpaper Engine/Services/SceneRuntime/SceneHierarchyResolver.swift' \
  'Open Wallpaper Engine.xcodeproj/project.pbxproj' \
  Tests/SceneRuntimeTests/main.swift scripts/test-scene-runtime.sh
git commit -m 'feat: resolve scene parent hierarchies'
```

---

### Task 2: Build the SpriteKit Parent Tree

**Files:**
- Modify: `Open Wallpaper Engine/Services/SceneWallpaperViewModel.swift`
- Modify: `Open Wallpaper Engine/Services/SceneRuntime/WESpriteScene.swift`
- Test: `Tests/SceneRuntimeTests/main.swift`

**Interfaces:**
- Consumes: `SceneHierarchyResolver.resolve(_:)` and every renderable object's source index, ID, parent ID, and `SKNode`.
- Produces: `WESpriteScene.attach(nodes:records:)`, attaching each node to a parent node or scene root while preserving the node's authored local transform and accumulated scene Z.

- [ ] **Step 1: Write failing attachment tests**

Add a SpriteKit test with root, child, and grandchild nodes. Require the child parent pointers to match, local positions to remain unchanged, and `accumulatedZPosition` to equal each source index. Add a missing-parent case that remains under the scene root.

```swift
let scene = WESpriteScene(size: CGSize(width: 2580, height: 1080))
let parent = SKNode()
let roof = SKNode()
scene.attach(
    nodes: [parent, roof],
    records: [
        SceneHierarchyRecord(id: 170, parentID: nil, sourceIndex: 0),
        SceneHierarchyRecord(id: 198, parentID: 170, sourceIndex: 1)
    ]
)
expect(roof.parent === parent, "roof is attached to its authored house parent")
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
WE_MAPLE_WALLPAPER='/Users/woody/Documents/Open Wallpaper Engine/3011747820' \
WE_HAPPYVILLE_WALLPAPER='/Users/woody/Documents/Open Wallpaper Engine/3121564310' \
./scripts/test-scene-runtime.sh
```

Expected: compilation fails because `WESpriteScene.attach(nodes:records:)` does not exist.

- [ ] **Step 3: Implement scene attachment**

Add `attach(nodes:records:)`. Resolve all records first, attach root nodes to the scene, attach valid children to their selected parent node, and log fallbacks without aborting.

```swift
func attach(nodes: [SKNode], records: [SceneHierarchyRecord]) {
    let attachments = SceneHierarchyResolver.resolve(records)
    for index in nodes.indices {
        switch attachments[index] {
        case .root(let localZ, _):
            nodes[index].zPosition = localZ
            addChild(nodes[index])
        case .parent(let parentIndex, let localZ):
            nodes[index].zPosition = localZ
            nodes[parentIndex].addChild(nodes[index])
        }
    }
}
```

- [ ] **Step 4: Convert scene construction to two phases**

In `buildSKScene`, build image and particle nodes in source order without immediately attaching them. Keep runtime bindings unchanged, collect matching hierarchy records, then call `skScene.attach(nodes:records:)` once all renderable nodes exist. The preview fallback remains a root child only when no images were built.

- [ ] **Step 5: Run regression tests and verify GREEN**

Run the command from Step 2.

Expected: all model, hierarchy, Happyville, Henesys, animation, movement, scroll, and audio tests pass.

- [ ] **Step 6: Commit**

```bash
git add 'Open Wallpaper Engine/Services/SceneWallpaperViewModel.swift' \
  'Open Wallpaper Engine/Services/SceneRuntime/WESpriteScene.swift' \
  Tests/SceneRuntimeTests/main.swift
git commit -m 'fix: render scene objects through parent hierarchy'
```

---

### Task 3: Build, Install, and Visually Verify Happyville

**Files:**
- No source files added.
- Install target: `/Applications/Open Wallpaper Engine.app`
- Backup target: `/private/tmp/Open Wallpaper Engine.before-parent-hierarchy-fix-20260729.app`

**Interfaces:**
- Consumes: the completed source tree and Happyville fixture.
- Produces: a signed Universal local application installed for user testing.

- [ ] **Step 1: Run the complete fresh test suite**

```bash
WE_MAPLE_WALLPAPER='/Users/woody/Documents/Open Wallpaper Engine/3011747820' \
WE_HAPPYVILLE_WALLPAPER='/Users/woody/Documents/Open Wallpaper Engine/3121564310' \
./scripts/test-scene-runtime.sh
```

Expected: `All scene runtime tests passed`.

- [ ] **Step 2: Build Universal Release**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 'Open Wallpaper Engine.xcodeproj' \
  -scheme 'Open Wallpaper Engine' \
  -configuration Release \
  -derivedDataPath /private/tmp/owe-universal-release \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Sign and validate the build**

```bash
codesign --force --deep --sign - \
  '/private/tmp/owe-universal-release/Build/Products/Release/Open Wallpaper Engine.app'
codesign --verify --deep --strict --verbose=2 \
  '/private/tmp/owe-universal-release/Build/Products/Release/Open Wallpaper Engine.app'
lipo -archs \
  '/private/tmp/owe-universal-release/Build/Products/Release/Open Wallpaper Engine.app/Contents/MacOS/Open Wallpaper Engine'
```

Expected: valid signature and `x86_64 arm64`.

- [ ] **Step 4: Back up, install, and relaunch**

Stop only Open Wallpaper Engine, move the existing app to the explicit backup target, install the signed build with `ditto`, and reopen it.

- [ ] **Step 5: Verify the original symptom**

Capture the desktop after loading Happyville. Compare it with the packaged `preview.gif`: the house at scene ID 170 must include child IDs 166 and 198 at parent-relative positions, while the Santa sleigh must move left between screenshots taken five seconds apart.

- [ ] **Step 6: Verify repository scope**

```bash
git diff --check
git status --short
git rev-list --left-right --count woody/main...HEAD
```

Expected: no uncommitted source changes, local commits only, no ZIP modification, and no push.
