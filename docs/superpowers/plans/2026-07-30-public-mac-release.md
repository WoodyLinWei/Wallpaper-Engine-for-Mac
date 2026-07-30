# Public Mac Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the current maintained macOS build as a public GitHub repository with accurate Traditional Chinese documentation and a directly downloadable Universal ZIP.

**Architecture:** Keep source, tests, documentation, and a fallback ZIP in the distribution repository. Build the app reproducibly with Xcode into a temporary derived-data directory, validate the Universal executable and archive contents, then publish the same ZIP as a GitHub Release asset.

**Tech Stack:** Swift, SwiftUI, SpriteKit, Xcode `xcodebuild`, `ditto`, Git, GitHub Releases

## Global Constraints

- Distribution repository: `WoodyLinWei/Wallpaper-Engine-for-Mac`
- Upstream contribution fork remains source-only.
- Release tag: `v0.8.1-scene-runtime.1`
- Minimum supported macOS version remains macOS 13.
- The distributed app is unsigned and unnotarized.
- Do not publish Workshop assets, credentials, private paths, keys, provisioning profiles, or certificates.

---

### Task 1: Public documentation

**Files:**
- Modify: `README.zh-TW.md`
- Modify: `DOWNLOAD.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: Current scene-runtime feature set and known limitations.
- Produces: Accurate public installation, usage, troubleshooting, and download instructions.

- [ ] **Step 1: Update the Traditional Chinese README**

Add a top-level download section linking to:

```text
https://github.com/WoodyLinWei/Wallpaper-Engine-for-Mac/releases/latest
```

Document Universal Mac support, Gatekeeper first launch, Steam Workshop setup,
local folder/ZIP import, scene animation/audio support, multi-display audio
deduplication, and current limitations.

- [ ] **Step 2: Update the concise download page**

Make `DOWNLOAD.md` point to both the latest GitHub Release and:

```text
dist/Open-Wallpaper-Engine-Mac-Universal.zip
```

Include right-click Open and System Settings > Privacy & Security fallback
instructions without recommending that users disable Gatekeeper globally.

- [ ] **Step 3: Correct the English README status**

Remove the obsolete statement that animated scene sprites are unsupported and
add the public release download link.

- [ ] **Step 4: Validate documentation**

Run:

```bash
rg -n 'releases/latest|Universal|Gatekeeper|GPL-3.0|已知限制' README.zh-TW.md DOWNLOAD.md README.md
git diff --check
```

Expected: all required topics are found and `git diff --check` exits 0.

- [ ] **Step 5: Commit**

```bash
git add README.zh-TW.md README.md DOWNLOAD.md
git commit -m "docs: prepare public Mac distribution"
```

### Task 2: Universal application archive

**Files:**
- Modify: `dist/Open-Wallpaper-Engine-Mac-Universal.zip`

**Interfaces:**
- Consumes: Release app from Xcode build products.
- Produces: One ZIP containing `Open Wallpaper Engine.app`.

- [ ] **Step 1: Run scene-runtime tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/test-scene-runtime.sh
```

Expected final line:

```text
All scene runtime tests passed
```

- [ ] **Step 2: Build the unsigned Universal Release app**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "Open Wallpaper Engine.xcodeproj" \
  -scheme "Open Wallpaper Engine" \
  -configuration Release \
  -derivedDataPath /private/tmp/owe-public-release-derived \
  CODE_SIGNING_ALLOWED=NO build
```

Expected final line:

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 3: Verify executable architectures**

Run:

```bash
lipo -archs "/private/tmp/owe-public-release-derived/Build/Products/Release/Open Wallpaper Engine.app/Contents/MacOS/Open Wallpaper Engine"
```

Expected output contains both:

```text
x86_64 arm64
```

- [ ] **Step 4: Replace the distribution ZIP**

Run:

```bash
ditto -c -k --sequesterRsrc --keepParent \
  "/private/tmp/owe-public-release-derived/Build/Products/Release/Open Wallpaper Engine.app" \
  "dist/Open-Wallpaper-Engine-Mac-Universal.zip"
```

- [ ] **Step 5: Validate archive contents**

Run:

```bash
unzip -t dist/Open-Wallpaper-Engine-Mac-Universal.zip
unzip -Z1 dist/Open-Wallpaper-Engine-Mac-Universal.zip
```

Expected: archive test reports no errors and every path begins with
`Open Wallpaper Engine.app/`.

- [ ] **Step 6: Commit**

```bash
git add dist/Open-Wallpaper-Engine-Mac-Universal.zip
git commit -m "release: refresh universal Mac app"
```

### Task 3: Public GitHub publication

**Files:**
- No source-file changes.

**Interfaces:**
- Consumes: Verified commits and ZIP from Tasks 1-2.
- Produces: Public repository, pushed `main`, and GitHub Release asset.

- [ ] **Step 1: Scan the outgoing repository changes**

Run:

```bash
git diff woody/main...HEAD --name-status
git ls-files | rg '(^|/)(private|\.ssh)(/|$)|\.(pem|key|p12|mobileprovision)$' || true
rg -n '/Users/woody|a26367758@gmail.com' README.md README.zh-TW.md DOWNLOAD.md scripts Tests || true
```

Expected: no private paths, keys, provisioning profiles, or credentials.

- [ ] **Step 2: Make the distribution repository public**

Update `WoodyLinWei/Wallpaper-Engine-for-Mac` visibility from private to public
using the authenticated GitHub API.

- [ ] **Step 3: Push main**

Run:

```bash
git push woody main
```

Expected: remote `main` advances to the local `HEAD`.

- [ ] **Step 4: Create the GitHub Release**

Create tag and release:

```text
v0.8.1-scene-runtime.1
```

Attach:

```text
dist/Open-Wallpaper-Engine-Mac-Universal.zip
```

Release notes summarize native scene animation, packaged audio, full-display
rendering, multi-display audio deduplication, installation, and limitations.

- [ ] **Step 5: Verify public delivery**

Verify:

- repository visibility is `public`;
- remote `main` SHA equals local `HEAD`;
- release tag targets local `HEAD`;
- release contains the Universal ZIP asset;
- the public download URL is returned by GitHub.
