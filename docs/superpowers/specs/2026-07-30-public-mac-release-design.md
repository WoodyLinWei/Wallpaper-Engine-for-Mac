# Public Mac Release Design

## Goal

Publish the maintained macOS build as a public, easy-to-install GitHub project
for people who do not have Xcode.

## Repository Roles

- `WoodyLinWei/Wallpaper-Engine-for-Mac` is the public distribution repository.
- `WoodyLinWei/wallpaper-engine-mac` remains the clean GitHub fork used for
  upstream pull requests.
- The distribution repository may include compiled release archives; the
  upstream contribution fork must remain source-only.

## Public Documentation

The Traditional Chinese README is the primary entry point and must include:

- a direct download link to the latest GitHub Release;
- a repository fallback link to the Universal ZIP;
- installation and first-launch Gatekeeper instructions;
- Steam Workshop download and local import instructions;
- an accurate list of supported scene features and known limitations;
- multi-display audio behavior and troubleshooting;
- GPL-3.0 attribution and a clear unofficial-project disclaimer.

English and Japanese readers continue to have links to their existing README
files. `DOWNLOAD.md` provides a concise installation-only page.

## Release Artifact

Build the Release configuration for both Apple Silicon and Intel with Xcode,
without a developer signing identity. Package only
`Open Wallpaper Engine.app` into:

`dist/Open-Wallpaper-Engine-Mac-Universal.zip`

The archive is attached to a GitHub Release and also committed to the
distribution repository as a fallback.

## Versioning

Use release tag `v0.8.1-scene-runtime.1` for this first public scene-runtime
build. Future runtime releases increment the final numeric component.

## Validation

Before publishing:

1. Run the standalone scene-runtime tests.
2. Build the unsigned Universal Release app.
3. Verify the executable contains `arm64` and `x86_64`.
4. Validate the ZIP and confirm it contains only the app bundle.
5. Scan tracked release changes for private paths, credentials, Steam assets,
   and private keys.
6. Verify repository visibility, pushed commit SHA, release tag, and download
   asset after publication.

## Safety and Scope

- Do not include downloaded Workshop wallpapers, audio, Steam credentials,
  API keys, provisioning profiles, or signing certificates.
- Do not claim full Wallpaper Engine compatibility.
- Explain that unsupported SceneScript, shaders, DXT textures, and some
  effects may render differently from Windows.
- Keep the app unsigned and unnotarized unless a future release explicitly
  adds an Apple Developer signing workflow.
