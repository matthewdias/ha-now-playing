# Contributing to HA Now Playing

## Building locally

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/matthewdias/ha-now-playing
cd ha-now-playing
xcodegen
open HANowPlaying.xcodeproj
```

Debug builds are unsigned — no Apple Developer account required. If you edit `project.yml`, re-run `xcodegen` to regenerate the `.xcodeproj` before building.

## Project structure

```
Sources/HANowPlaying/
  AppState.swift              # Central hub — owns and wires all subsystems
  HANowPlayingApp.swift       # App entry point
  HA/
    HomeAssistantClient.swift # WebSocket client, auth, entity state/diffs
    ActiveEntitySelector.swift# Auto/manual active entity selection
    EntityParsing.swift       # HA attribute → MediaPlayerState mapping
  Models/
    HAConnectionState.swift   # WebSocket connection state enum
    HAMessage.swift           # WebSocket wire types
    MediaPlayerState.swift    # Core domain struct
  NowPlaying/
    NowPlayingController.swift# MPNowPlayingInfoCenter + MPRemoteCommandCenter
  Persistence/
    Credentials.swift         # CredentialStore protocol + Keychain/UserDefaults implementations
  UI/
    MenuBarView.swift         # Menu bar popover
    SettingsView.swift        # Credentials + entity selection UI
    HAConnectionState+UI.swift# Connection state display helpers
  Updates/
    UpdateController.swift    # Sparkle integration (disabled in DEBUG builds)

Tests/HANowPlayingTests/
  Mocks/
    MockHAClient.swift        # Test double for HAClient
```

The data flow is: `HomeAssistantClient` receives WebSocket diffs → `ActiveEntitySelector` picks the active entity → `NowPlayingController` pushes state to macOS. `AppState` owns all three and wires them together via `withObservationTracking`.

## Running tests

```bash
xcodebuild test -scheme HANowPlaying -destination 'platform=macOS'
```

Or run them from Xcode with **Cmd+U**.

## Coding standards

- Use `@Bindable` when binding to an `@Observable` dependency passed in from outside
- Prefer value types (structs); only use classes where reference semantics are required
- Use typed errors conforming to `LocalizedError` rather than `String` or untyped errors
- Keep SwiftUI views under ~100 lines; extract subviews and custom modifiers when they grow beyond that
- Add `accessibilityLabel` to all icon-only controls

## AI coding agents

[AGENTS.md](AGENTS.md) contains architecture context for AI agents. It is supplementary — README and CONTRIBUTING are the source of truth for humans.

If you use **Claude Code**, `.claude/settings.json` is checked in with a PostToolUse hook that runs `swiftlint --fix` automatically after each file edit. Other agents should run `swiftlint --fix Sources Tests` manually before committing.

## Pull requests

- Open an issue first for anything beyond a small bug fix so we can align on approach
- Update this file and the README if your change affects how to build, test, or contribute
