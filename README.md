# Portals

A macOS menu bar app that snapshots and restores window layouts per display with multiple profiles. Works on macOS Sonoma, Sequoia, and newer.

## Features
- Save and restore window positions per display using normalized frames (adapts to resolution changes).
- Multiple named profiles; switch via the menu bar picker.
- Global hotkeys: `⌃⌥⌘S` (save snapshot), `⌃⌥⌘R` (restore).
- Missing displays are skipped; extra windows are staged to the center of the main display.
- Screen flash feedback on snapshot; persisted profiles stored in Application Support.

## Requirements
- macOS 14+ (targets Sonoma/Sequoia and forward).
- Accessibility permission (System Settings → Privacy & Security → Accessibility). Without this, snapshots/restores are disabled.

## Download
Grab the ready-to-run DMG from GitHub Releases: [Portals.dmg](https://github.com/Cesar-Carrio/portals/releases/latest/download/Portals.dmg).

## Build & Run
```bash
swift build
swift run
```

The app runs as a menu bar extra. Use the picker to switch profiles, type a name and press Return to add a new profile, then use Save/Restore buttons or the hotkeys.

### Update the app icon
```bash
# Refresh the base artwork (renders a portal-inspired gradient icon)
swift -module-cache-path .build/ModuleCache Scripts/generate_icon.swift
# Build the iconset and .icns bundle asset
bash Scripts/build_app_icon.sh
```
Packaging will automatically embed `Assets/AppIcon.icns` if it exists.

### Keep Accessibility approval sticky
macOS ties Accessibility approval to the app’s code signature. If you run ad-hoc/unsigned builds (the default), every rebuild looks like a new app and macOS will ask for permission again. Sign with a stable identity to stop the repeated prompts:

```bash
IDENTITY="Apple Development: Your Name (TEAMID)" bash Scripts/package.sh
# then move dist/Portals.app into /Applications and approve it once
```

You can also set `IDENTITY` when packaging a release DMG so the distributed app keeps the same signature across updates.

## Build a DMG for download
1) `bash Scripts/package.sh` (override version via `VERSION=1.1.0 bash Scripts/package.sh`).
2) Outputs:
   - `dist/Portals.app` — runnable bundle (menu bar only; no Dock icon).
   - `dist/Portals.dmg` — share this file; users can open the DMG and drag Portals.app to Applications.
3) If distributing broadly, sign/notarize the app: `codesign --deep --force --options runtime --sign "<Identity>" dist/Portals.app` then notarize via `notarytool` and rebuild the DMG.
4) Upload `dist/Portals.dmg` to GitHub Releases (the README download link expects the asset to be named `Portals.dmg`).

## Notes & Limitations
- Spaces/desktops: macOS does not provide a reliable API to move windows across Spaces; the app operates in the current Space.
- Some system windows or apps may refuse to move via Accessibility APIs.
- Full-screen and minimized windows are ignored when capturing.

## Release Checklist
- Ensure Accessibility permission is granted on target machines.
- If distributing outside your machine, sign/notarize the built app bundle (this repo currently builds/runs via `swift run`).
- Verify hotkeys do not conflict with other global shortcuts on your system.

## License
MIT — see [LICENSE](LICENSE).
