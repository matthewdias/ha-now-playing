import Foundation

enum PlaybackState: String, Sendable {
    case playing, paused, idle, off, unavailable, unknown
    var isActive: Bool { self == .playing || self == .paused }
}

enum RepeatMode: String, Sendable {
    case off, all, one

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    var systemImage: String { self == .one ? "repeat.1" : "repeat" }
}

/// HA `supported_features` bitmask decoded into named capabilities.
struct MediaPlayerEntityFeature: OptionSet {
    let rawValue: Int
    static let seek          = MediaPlayerEntityFeature(rawValue: 2)
    static let volumeSet     = MediaPlayerEntityFeature(rawValue: 4)
    static let volumeMute    = MediaPlayerEntityFeature(rawValue: 8)
    static let previousTrack = MediaPlayerEntityFeature(rawValue: 16)
    static let nextTrack     = MediaPlayerEntityFeature(rawValue: 32)
    static let shuffle       = MediaPlayerEntityFeature(rawValue: 32768)
    static let `repeat`      = MediaPlayerEntityFeature(rawValue: 262144)
}

/// Snapshot of a single HA `media_player` entity — the core domain type that flows through the entire pipeline.
/// Built from a full entity payload by `HomeAssistantClient.buildState` and updated incrementally by `applyChange`.
struct MediaPlayerState: Identifiable, Equatable, Sendable {
    let entityId: String
    let friendlyName: String
    let playbackState: PlaybackState
    // Core track info
    let mediaTitle: String?
    let mediaArtist: String?
    let mediaAlbumName: String?
    let mediaAlbumArtist: String?
    // Content type & context
    let mediaContentType: String?
    let mediaSeriesTitle: String?
    let mediaSeason: String?
    let mediaEpisode: String?
    let mediaChannel: String?
    let appName: String?
    let appId: String?
    // Artwork
    let entityPicture: String?
    // Playback position
    let mediaDuration: Double?
    let mediaPosition: Double?
    let mediaPositionUpdatedAt: Date?
    // Capabilities
    let supportedFeaturesRaw: Int
    // Playback modes
    let shuffle: Bool
    let repeatMode: RepeatMode
    // Volume
    let volume: Double?
    let isMuted: Bool

    var id: String { entityId }

    // MARK: - Content-type-aware display

    var primaryTitle: String { mediaTitle ?? friendlyName }

    var secondaryTitle: String? {
        switch mediaContentType {
        case "tvshow", "episode": return mediaSeriesTitle ?? appName ?? mediaArtist
        case "channel":           return mediaChannel ?? appName
        case "movie":             return appName
        default:                  return mediaArtist
        }
    }

    var tertiaryTitle: String? {
        switch mediaContentType {
        case "tvshow", "episode":
            var ep = ""
            if let s = mediaSeason { ep += "S\(s)" }
            if let e = mediaEpisode { ep += "E\(e)" }
            return ep.isEmpty ? nil : ep
        case "music", nil:
            return mediaAlbumName
        default:
            return nil
        }
    }

    // MARK: - Capability flags

    var isLiveStream: Bool { mediaContentType == "channel" || mediaContentType == "url" }

    private var features: MediaPlayerEntityFeature { MediaPlayerEntityFeature(rawValue: supportedFeaturesRaw) }

    var supportsSeek: Bool { features.contains(.seek) }
    var supportsVolumeSet: Bool { features.contains(.volumeSet) }
    var supportsVolumeMute: Bool { features.contains(.volumeMute) }
    var supportsPreviousTrack: Bool { features.contains(.previousTrack) }
    var supportsNextTrack: Bool { features.contains(.nextTrack) }
    var supportsShuffle: Bool { features.contains(.shuffle) }
    var supportsRepeat: Bool { features.contains(.repeat) }

    var interpolatedPosition: Double? {
        guard let base = mediaPosition, let updatedAt = mediaPositionUpdatedAt else { return nil }
        return playbackState == .playing
            ? max(0, base + Date().timeIntervalSince(updatedAt))
            : base
    }

    // Custom equality used by SwiftUI for diffing. Intentional omissions:
    // - mediaPositionUpdatedAt: position changes always arrive with mediaPosition; timestamp alone doesn't warrant a redraw.
    // - friendlyName, mediaAlbumName, mediaAlbumArtist, mediaContentType, mediaSeriesTitle,
    //   mediaSeason, mediaEpisode, mediaChannel, appName: secondary/tertiary display fields whose
    //   changes always accompany a title, state, or artwork change that is already included.
    static func == (lhs: MediaPlayerState, rhs: MediaPlayerState) -> Bool {
        lhs.entityId == rhs.entityId &&
        lhs.playbackState == rhs.playbackState &&
        lhs.mediaTitle == rhs.mediaTitle &&
        lhs.mediaArtist == rhs.mediaArtist &&
        lhs.mediaDuration == rhs.mediaDuration &&
        lhs.mediaPosition == rhs.mediaPosition &&
        lhs.entityPicture == rhs.entityPicture &&
        lhs.appId == rhs.appId &&
        lhs.supportedFeaturesRaw == rhs.supportedFeaturesRaw &&
        lhs.shuffle == rhs.shuffle &&
        lhs.repeatMode == rhs.repeatMode &&
        lhs.volume == rhs.volume &&
        lhs.isMuted == rhs.isMuted
    }
}
