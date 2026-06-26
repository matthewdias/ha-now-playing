# HA Now Playing — Agent Context

> For build instructions, project structure, and coding standards see [CONTRIBUTING.md](CONTRIBUTING.md).
> For project description, features, and setup see [README.md](README.md).

## Agent guidelines

- **TDD**: write tests before or alongside new logic. The test suite uses Swift Testing (`@Test`, `#expect`). New behaviour without tests will be flagged in review. Exemptions: UI views, app entry point, and thin delegation wiring with no logic of its own.
- Run `swiftlint lint --strict Sources Tests` before considering a change done. The PostToolUse hook runs SwiftLint automatically on every file edit, so violations are surfaced immediately.
- **Keep docs in sync**: when adding, moving, or deleting source files, update the project structure in `CONTRIBUTING.md` and the architecture descriptions in `AGENTS.md` in the same change.

## Architecture

Five layers form a pipeline from HA → macOS Now Playing:

```
HomeAssistantClient → ActiveEntitySelector → NowPlayingController
        ↓                      ↓                      ↓
    AppState ──────────────────────────────→ SwiftUI Views
```

- **`AppState`** — central hub; owns the three subsystems and wires them via `withObservationTracking`. `@Observable` so SwiftUI tracks nested changes automatically — no manual forwarding needed.
- **`HomeAssistantClient`** — WebSocket client. Authenticates, seeds state via `get_states`, then receives `subscribe_entities` diffs (`"a"`/`"c"`/`"r"` keys, changes nested under `"+"`). `buildEntityState` (in `EntityParsing.swift`) constructs a `MediaPlayerState` from a full payload; `applyEntityChange` merges a diff onto an existing one.
- **`ActiveEntitySelector`** — picks the active entity. Auto mode: most-recently-playing wins. Manual mode: user-pinned. Persists pin to `UserDefaults`.
- **`NowPlayingController`** — pushes state into `MPNowPlayingInfoCenter`; receives hardware/Control Center commands via `MPRemoteCommandCenter` and translates them to HA service calls. Has an in-memory artwork cache keyed by entity picture path or `"itunes:{bundleId}"`.
- **`HAConnectionState`** (`Models/HAConnectionState.swift`) — enum of WebSocket connection states: `disconnected`, `connecting`, `authenticating`, `connected`, `failed`.
- **`MediaPlayerState`** — the single domain struct. Content-type-aware display (`primaryTitle`, `secondaryTitle`, `tertiaryTitle`), capability bit flags, `effectiveArtworkPath`.
- **`HAMessage`** — all WebSocket wire types. `FlexibleString` handles attributes that HA sends as either String or Int (season/episode numbers). `ServiceValue` is a typed enum for service call payloads (`bool`, `double`, `string`).
- **`Credentials`** (`Persistence/Credentials.swift`) — `CredentialStore` protocol with two implementations: `KeychainCredentialStore` (production) and `UserDefaultsCredentialStore` (debug). Stores HA URL and token.
- **`UpdateController`** (`Updates/UpdateController.swift`) — Sparkle integration. Disabled in DEBUG builds. Tracks `updateAvailable` and `canCheckForUpdates` for the UI.

### Key HA protocol details

- `subscribe_entities` sends compact diffs: `"a"` (add), `"c"` (change), `"r"` (remove)
- Changes are wrapped under a `"+"` key within each entity's diff object
- `supported_features` is a bitmask: SEEK=2, VOLUME_SET=4, VOLUME_MUTE=8, PREV=16, NEXT=32, SHUFFLE=32768, REPEAT=262144
- When `app_id` changes in a diff, `entity_picture` must be cleared — it can't carry over from the previous app (stale CDN URLs). See `applyEntityChange` in `EntityParsing.swift`.

