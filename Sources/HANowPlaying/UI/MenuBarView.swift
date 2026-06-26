import SwiftUI
import Nuke

private let menuBarPopoverWidth: CGFloat = 280

struct MenuBarView: View {
    @Environment(AppState.self) var store
    @Environment(UpdateController.self) var updater
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            if !store.isConfigured {
                unconfiguredView
            } else if let entity = store.activeEntity {
                nowPlayingView(entity: entity)
            } else {
                idleView
            }

            Divider()
            bottomBar
        }
        .frame(width: menuBarPopoverWidth)
    }

    // MARK: - States

    private var unconfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemName: "house.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Connect to Home Assistant")
                .font(.headline)
            Text("Open Settings to enter your URL and access token.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") { openSettings() }
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }

    private var idleView: some View {
        VStack(spacing: 6) {
            connectionStatusView
            Text("Nothing playing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func nowPlayingView(entity: MediaPlayerState) -> some View {
        VStack(spacing: 12) {
            connectionWarning

            // Track info
            HStack(spacing: 12) {
                ArtworkView(entity: entity, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entity.primaryTitle)
                        .font(.headline)
                        .lineLimit(1)
                    if let sub = entity.secondaryTitle {
                        Text(sub)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let third = entity.tertiaryTitle {
                        Text(third)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }

            // Scrubber (hidden for live streams)
            if let duration = entity.mediaDuration, duration > 0, !entity.isLiveStream {
                PositionSlider(entity: entity)
            } else if entity.isLiveStream {
                liveStreamBadge
            }

            // Transport + shuffle/repeat
            TransportControls(entity: entity)

            // Volume (shown when supported)
            if entity.supportsVolumeSet || entity.supportsVolumeMute {
                VolumeControls(entity: entity)
            }
        }
        .padding(16)
    }

    private var liveStreamBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(.red).frame(width: 6, height: 6)
            Text("LIVE").font(.caption2.bold()).foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var connectionWarning: some View {
        switch store.connectionState {
        case .connected:
            EmptyView()
        default:
            connectionStatusView
        }
    }

    // MARK: - Connection status

    private var connectionStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.connectionState.color)
                .frame(width: 8, height: 8)
            Text(store.connectionState.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            Menu {
                Button("Auto") { store.selector.pin(entityId: nil) }
                Divider()
                ForEach(store.sortedEntities) { entity in
                    Button {
                        store.selector.pin(entityId: entity.entityId)
                    } label: {
                        HStack {
                            Text(entity.friendlyName)
                            if store.selector.activeEntityId == entity.entityId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(
                    store.activeEntity?.friendlyName ?? "Select Device",
                    systemImage: store.selector.isPinned ? "pin" : "speaker.wave.2"
                )
                .font(.caption)
            }
            .menuStyle(.borderlessButton)

            Spacer()

            Button {
                updater.checkForUpdates()
            } label: {
                Image(systemName: updater.updateAvailable ? "arrow.down.circle.fill" : "arrow.clockwise.circle")
                    .foregroundStyle(updater.updateAvailable ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!updater.canCheckForUpdates)
            .accessibilityLabel(updater.updateAvailable ? "Update Available" : "Check for Updates")

            Button { openSettings() } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Menu Bar Icon

struct MenuBarLabel: View {
    @Environment(AppState.self) var store

    var body: some View {
        if let entity = store.activeEntity, entity.playbackState == .playing {
            Image(systemName: "play.house")
        } else {
            Image(systemName: "music.note.house")
        }
    }
}

// MARK: - Transport Controls

struct TransportControls: View {
    let entity: MediaPlayerState
    @Environment(AppState.self) var store

    var body: some View {
        HStack(spacing: 0) {
            // Shuffle — left anchor
            Group {
                if entity.supportsShuffle {
                    Button {
                        store.sendCommand("shuffle_set", data: ["shuffle": .bool(!entity.shuffle)])
                    } label: {
                        Image(systemName: "shuffle")
                            .foregroundStyle(entity.shuffle ? Color.accentColor : .secondary)
                            .font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(entity.shuffle ? "Shuffle on" : "Shuffle off")
                } else {
                    Color.clear
                }
            }
            .frame(width: 28, alignment: .leading)

            Spacer()

            // Core transport
            HStack(spacing: 20) {
                if entity.supportsPreviousTrack {
                    Button { store.sendCommand("media_previous_track") } label: {
                        Image(systemName: "backward.fill").font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous")
                }

                Button {
                    store.sendCommand(entity.playbackState == .playing ? "media_pause" : "media_play")
                } label: {
                    Image(systemName: entity.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entity.playbackState == .playing ? "Pause" : "Play")

                if entity.supportsNextTrack {
                    Button { store.sendCommand("media_next_track") } label: {
                        Image(systemName: "forward.fill").font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next")
                }
            }

            Spacer()

            // Repeat — right anchor
            Group {
                if entity.supportsRepeat {
                    Button {
                        store.sendCommand("repeat_set", data: ["repeat": .string(entity.repeatMode.next.rawValue)])
                    } label: {
                        Image(systemName: entity.repeatMode.systemImage)
                            .foregroundStyle(entity.repeatMode == .off ? .secondary : Color.accentColor)
                            .font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Repeat \(entity.repeatMode.rawValue)")
                } else {
                    Color.clear
                }
            }
            .frame(width: 28, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Volume Controls

struct VolumeControls: View {
    let entity: MediaPlayerState
    @Environment(AppState.self) var store
    @State private var localVolume: Double = 0
    @State private var isEditing = false
    @State private var sendTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 8) {
            Button {
                guard entity.supportsVolumeMute else { return }
                store.sendCommand("volume_mute", data: ["is_volume_muted": .bool(!entity.isMuted)])
            } label: {
                Image(systemName: volumeIcon)
                    .frame(width: 18)
                    .foregroundStyle(entity.isMuted ? .secondary : .primary)
            }
            .buttonStyle(.plain)
            .disabled(!entity.supportsVolumeMute)
            .accessibilityLabel(entity.isMuted ? "Unmute" : "Mute")

            if entity.supportsVolumeSet {
                Slider(value: $localVolume, in: 0...1, onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        // Drag released — cancel debounce and send immediately
                        sendTask?.cancel()
                        store.sendCommand("volume_set", data: ["volume_level": .double(localVolume)])
                    }
                })
                .onAppear { localVolume = entity.volume ?? 0 }
                .onChange(of: entity.volume) { _, newVal in
                    // Sync from HA when not actively dragging
                    if !isEditing { localVolume = newVal ?? localVolume }
                }
                .onChange(of: localVolume) { _, newVal in
                    // Handles clicks: onEditingChanged doesn't fire for clicks on macOS,
                    // so send via a short debounce when not in a drag
                    guard !isEditing else { return }
                    sendTask?.cancel()
                    sendTask = Task {
                        try? await Task.sleep(for: .milliseconds(80))
                        if !Task.isCancelled {
                            store.sendCommand("volume_set", data: ["volume_level": .double(newVal)])
                        }
                    }
                }
            }
        }
    }

    private var volumeIcon: String {
        if entity.isMuted || (entity.volume ?? 1) == 0 { return "speaker.slash.fill" }
        let v = entity.volume ?? 1
        if v < 0.33 { return "speaker.wave.1.fill" }
        if v < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

// MARK: - Position Slider

struct PositionSlider: View {
    let entity: MediaPlayerState
    @Environment(AppState.self) var store
    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let position = isDragging ? dragValue : (entity.interpolatedPosition ?? 0)
            VStack(spacing: 2) {
                Slider(
                    value: isDragging ? $dragValue : .init(
                        get: { entity.interpolatedPosition ?? 0 },
                        set: { dragValue = $0 }
                    ),
                    in: 0...(entity.mediaDuration ?? 1),
                    onEditingChanged: { editing in
                        if editing { dragValue = entity.interpolatedPosition ?? 0 }
                        isDragging = editing
                        if !editing {
                            store.sendCommand("media_seek", data: ["seek_position": .double(dragValue)])
                        }
                    }
                )
                HStack {
                    Text(formatTime(position))
                    Spacer()
                    Text(formatTime(entity.mediaDuration ?? 0))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Artwork

struct ArtworkView: View {
    let entity: MediaPlayerState
    let size: CGFloat
    @Environment(AppState.self) var store
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(.quaternary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: "\(entity.entityId)|\(entity.mediaTitle ?? "")") {
            image = nil
            image = await resolveArtwork()
        }
    }

    private func resolveArtwork() async -> NSImage? {
        // 1. Try entity_picture (or any HA-proxied path)
        if let path = entity.entityPicture,
           let request = store.artworkRequest(for: path),
           let img = try? await ImagePipeline.shared.image(for: ImageRequest(urlRequest: request)) {
            return img
        }
        // 2. Fall back to app icon via iTunes lookup
        if let bundleId = entity.appId,
           let iconURL = await iTunesIconURL(for: bundleId),
           let img = try? await ImagePipeline.shared.image(for: ImageRequest(url: iconURL)) {
            return img
        }
        return nil
    }

    private func iTunesIconURL(for bundleId: String) async -> URL? {
        guard let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&entity=software"),
              let (data, _) = try? await URLSession.shared.data(from: lookupURL) else { return nil }
        struct Response: Decodable {
            struct App: Decodable { let artworkUrl512: String? }
            let results: [App]
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              let urlStr = response.results.first?.artworkUrl512 else { return nil }
        return URL(string: urlStr)
    }
}
