# LyricDrive

Personal iOS lyrics app — large readable synced lyrics while driving. Built with SwiftUI for **iOS 18+**.
still in building process, solving one problem at a time

> **No Mac?** See **[BUILD_WITHOUT_MAC.md](BUILD_WITHOUT_MAC.md)** for GitHub Actions build + Windows sideload instructions.

## Features

- Synced LRC lyrics with auto-scroll and line highlighting
- Works with **Spotify, Apple Music, YouTube Music** (via Now Playing polling)
- ShazamKit fallback when metadata is missing
- Manual search (LRCLIB)
- Offline cache (SwiftData)
- 4 themes + Driving font size
- Live Activity / Dynamic Island (optional)
- Lock screen widget (via App Group)
- CarPlay UI (requires optional CarPlay entitlement)

## Quick start (if you have a Mac)

```bash
brew install xcodegen
xcodegen generate
open LyricDrive.xcodeproj
```

Run on a **physical iPhone** for Now Playing, Shazam, and widgets.

## Personal use setup

1. Change bundle ID in `project.yml` to something unique
2. Sign with your free Apple ID in Xcode
3. Install on device
4. Settings → **Driving** font + **AMOLED Black** or **Car Dashboard Red** theme
5. Keep LyricDrive open (or in background) while music plays

## Playback controls

| App | In-app controls |
|-----|-----------------|
| Apple Music | Works |
| Spotify / YouTube Music | Use their app or Lock Screen controls |

## Project structure

See folders under `LyricDrive/`, `LyricDriveWidget/`, `LyricDriveTests/`.

## CarPlay (optional)

Default entitlements exclude CarPlay (easier free signing). To enable later, set in `project.yml`:

```yaml
CODE_SIGN_ENTITLEMENTS: LyricDrive/Resources/LyricDrive.carplay.entitlements
```

Requires Apple CarPlay entitlement approval.

## Tests

```bash
xcodebuild test -scheme LyricDrive -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or push to GitHub — CI runs tests automatically.

## License

Personal use. Lyrics from [LRCLIB](https://lrclib.net/) — respect their terms.
