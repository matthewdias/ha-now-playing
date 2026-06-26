import Foundation
import MediaPlayer
import AppKit
import Nuke

@MainActor
final class NowPlayingController {
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var artworkTask: Task<Void, Never>?

    private weak var client: (any HAClient)?
    private var currentEntityId: String?
    private var lastArtworkKey: String?

    func setUp(client: any HAClient) {
        self.client = client
        registerCommands()
    }

    func update(state: MediaPlayerState?, client: any HAClient) {
        self.client = client

        guard let state = state, state.playbackState.isActive else {
            clearNowPlaying()
            return
        }

        currentEntityId = state.entityId

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle]            = state.primaryTitle
        info[MPMediaItemPropertyArtist]           = state.secondaryTitle
        info[MPMediaItemPropertyAlbumTitle]       = state.mediaAlbumName
        info[MPMediaItemPropertyAlbumArtist]      = state.mediaAlbumArtist
        info[MPMediaItemPropertyMediaType]        = mpMediaType(for: state.mediaContentType)
        info[MPNowPlayingInfoPropertyIsLiveStream] = state.isLiveStream
        info[MPMediaItemPropertyPlaybackDuration] = state.isLiveStream ? nil : state.mediaDuration

        if !state.isLiveStream, let pos = state.interpolatedPosition {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = pos
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = state.playbackState == .playing ? 1.0 : 0.0

        // Preserve artwork across metadata-only updates so Control Center doesn't
        // go blank between the async fetch completing and the next update arriving.
        if let artwork = infoCenter.nowPlayingInfo?[MPMediaItemPropertyArtwork] {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        let artworkKey = state.entityPicture ?? state.appId.map { "itunes:\($0)" }
        if artworkKey != lastArtworkKey {
            lastArtworkKey = artworkKey
            fetchArtwork(for: state)
        }

        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = state.playbackState == .playing ? .playing : .paused

        configureCommands(for: state)
    }

    // MARK: - Private

    private func clearNowPlaying() {
        artworkTask?.cancel()
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
        currentEntityId = nil
        lastArtworkKey = nil
    }

    private func fetchArtwork(for state: MediaPlayerState) {
        artworkTask?.cancel()
        artworkTask = Task {
            guard let image = await resolveArtworkImage(for: state) else { return }
            guard !Task.isCancelled else { return }
            let artwork = Self.makeArtwork(from: image)
            var info = self.infoCenter.nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = artwork
            self.infoCenter.nowPlayingInfo = info
        }
    }

    // MPMediaItemArtwork's requestHandler is invoked by MediaPlayer on its own
    // (non-main) accessQueue. Under the Swift 6 language mode, a closure created
    // inside @MainActor code is inferred @MainActor-isolated; when MediaPlayer calls
    // it off the main actor the runtime dispatch_assert_queue check fails and the app
    // crashes (swiftlang/swift#75453). Building the artwork in a nonisolated context
    // keeps the handler free of main-actor isolation.
    nonisolated static func makeArtwork(from image: NSImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func resolveArtworkImage(for state: MediaPlayerState) async -> NSImage? {
        // 1. Try entity_picture
        if let path = state.entityPicture,
           let request = client?.artworkRequest(for: path),
           let img = try? await ImagePipeline.shared.image(for: ImageRequest(urlRequest: request)) {
            return img
        }
        // 2. Fall back to iTunes app icon
        if let bundleId = state.appId,
           let iconURL = await iTunesIconURL(for: bundleId),
           let img = try? await ImagePipeline.shared.image(for: ImageRequest(url: iconURL)) {
            return img
        }
        return nil
    }

    private func iTunesIconURL(for bundleId: String) async -> URL? {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&entity=software"),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        struct Response: Decodable {
            struct App: Decodable { let artworkUrl512: String? }
            let results: [App]
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              let urlStr = response.results.first?.artworkUrl512 else { return nil }
        return URL(string: urlStr)
    }

    private func mpMediaType(for contentType: String?) -> UInt {
        switch contentType {
        case "music":           return MPMediaType.music.rawValue
        case "podcast":         return MPMediaType.podcast.rawValue
        case "tvshow", "episode": return MPMediaType.tvShow.rawValue
        case "movie":           return MPMediaType.movie.rawValue
        case "musicvideo":      return MPMediaType.musicVideo.rawValue
        default:                return MPMediaType.music.rawValue
        }
    }

    // MARK: - Remote command registration

    private func registerCommands() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.sendCommand(service: "media_play"); return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.sendCommand(service: "media_pause"); return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.sendCommand(service: "media_play_pause"); return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.sendCommand(service: "media_next_track"); return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.sendCommand(service: "media_previous_track"); return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.sendCommand(service: "media_seek", data: ["seek_position": .double(e.positionTime)])
            return .success
        }
        commandCenter.changeShuffleModeCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangeShuffleModeCommandEvent else { return .commandFailed }
            let on = e.shuffleType != .off
            self?.sendCommand(service: "shuffle_set", data: ["shuffle": .bool(on)])
            return .success
        }
        commandCenter.changeRepeatModeCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangeRepeatModeCommandEvent else { return .commandFailed }
            let mode: String
            switch e.repeatType {
            case .off: mode = "off"
            case .one: mode = "one"
            default:   mode = "all"
            }
            self?.sendCommand(service: "repeat_set", data: ["repeat": .string(mode)])
            return .success
        }
    }

    private func configureCommands(for state: MediaPlayerState) {
        commandCenter.playCommand.isEnabled                    = true
        commandCenter.pauseCommand.isEnabled                   = true
        commandCenter.togglePlayPauseCommand.isEnabled         = true
        commandCenter.nextTrackCommand.isEnabled               = state.supportsNextTrack
        commandCenter.previousTrackCommand.isEnabled           = state.supportsPreviousTrack
        commandCenter.changePlaybackPositionCommand.isEnabled  = state.supportsSeek && !state.isLiveStream
        commandCenter.changeShuffleModeCommand.isEnabled       = state.supportsShuffle
        commandCenter.changeRepeatModeCommand.isEnabled        = state.supportsRepeat

        if state.supportsShuffle {
            commandCenter.changeShuffleModeCommand.currentShuffleType = state.shuffle ? .items : .off
        }
        if state.supportsRepeat {
            commandCenter.changeRepeatModeCommand.currentRepeatType = {
                switch state.repeatMode {
                case .off: return .off
                case .one: return .one
                case .all: return .all
                }
            }()
        }
    }

    private func sendCommand(service: String, data: [String: ServiceValue] = [:]) {
        guard let entityId = currentEntityId, let client = client else { return }
        client.callService(domain: "media_player", service: service, entityId: entityId, data: data)
    }
}
