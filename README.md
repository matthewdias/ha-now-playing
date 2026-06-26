# HA Now Playing

A macOS menu bar app that bridges Home Assistant `media_player` entities into the native macOS Now Playing experience — Control Center, Lock Screen, and hardware media keys all work with whatever is playing in HA.

## Features

- Shows the active media player's title, artist, album art, and playback state in the macOS Now Playing widget
- Hardware media keys (play/pause, next, previous) and Control Center controls send commands back to Home Assistant
- Automatically tracks the most recently active player, or pin a specific entity
- Volume and mute controls
- Supports shuffle and repeat where the player allows

## Requirements

- macOS 15 or later
- Home Assistant 2023.4 or later (requires `subscribe_entities` support)

## Installation

Download the latest `HANowPlaying.dmg` from [Releases](https://github.com/matthewdias/ha-now-playing/releases), open it, and drag HA Now Playing to your Applications folder.

## Setup

1. In Home Assistant, create a **Long-Lived Access Token** (Profile → Security → Long-Lived Access Tokens)
2. Launch HA Now Playing and open Settings from the menu bar icon
3. Enter your Home Assistant URL (e.g. `http://homeassistant.local:8123`) and paste the token
4. The app connects automatically and begins tracking your media players

## Building from source

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/matthewdias/ha-now-playing
cd ha-now-playing
xcodegen
open HANowPlaying.xcodeproj
```

Then hit **Run** in Xcode.
