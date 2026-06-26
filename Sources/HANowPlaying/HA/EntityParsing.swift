import Foundation

func buildEntityState(
    entityId: String,
    stateStr: String,
    attrs: HAAttributes?,
    lastUpdated: String? = nil,
    lastUpdatedDate: Date? = nil,
    using formatter: ISO8601DateFormatter
) -> MediaPlayerState {
    let posDate: Date?
    if let s = attrs?.mediaPositionUpdatedAt {
        posDate = formatter.date(from: s)
    } else {
        posDate = lastUpdatedDate ?? lastUpdated.flatMap { formatter.date(from: $0) }
    }

    return MediaPlayerState(
        entityId: entityId,
        friendlyName: attrs?.friendlyName ?? entityId,
        playbackState: PlaybackState(rawValue: stateStr) ?? .unknown,
        mediaTitle: attrs?.mediaTitle,
        mediaArtist: attrs?.mediaArtist,
        mediaAlbumName: attrs?.mediaAlbumName,
        mediaAlbumArtist: attrs?.mediaAlbumArtist,
        mediaContentType: attrs?.mediaContentType,
        mediaSeriesTitle: attrs?.mediaSeriesTitle,
        mediaSeason: attrs?.mediaSeason?.stringValue,
        mediaEpisode: attrs?.mediaEpisode?.stringValue,
        mediaChannel: attrs?.mediaChannel,
        appName: attrs?.appName,
        appId: attrs?.appId,
        entityPicture: attrs?.entityPicture,
        mediaDuration: attrs?.mediaDuration,
        mediaPosition: attrs?.mediaPosition,
        mediaPositionUpdatedAt: posDate,
        supportedFeaturesRaw: attrs?.supportedFeatures ?? 0,
        shuffle: attrs?.shuffle ?? false,
        repeatMode: RepeatMode(rawValue: attrs?.repeatMode ?? "off") ?? .off,
        volume: attrs?.volumeLevel,
        isMuted: attrs?.isMuted ?? false
    )
}

func applyEntityChange(
    _ change: HAEntityChange,
    to state: MediaPlayerState,
    luDate: Date?,
    using formatter: ISO8601DateFormatter
) -> MediaPlayerState {
    let diff = change.added
    let attrs = diff?.a
    let posDate: Date?
    if let s = attrs?.mediaPositionUpdatedAt {
        posDate = formatter.date(from: s)
    } else {
        posDate = luDate ?? state.mediaPositionUpdatedAt
    }

    // If the app changed, stale entity_picture from the previous app must not carry over.
    // Swift's ?? can't distinguish "key absent from diff" from "key explicitly null",
    // so we use appId changing as the signal to clear artwork.
    let appChanged = attrs?.appId != nil && attrs?.appId != state.appId
    let resolvedPicture = appChanged ? attrs?.entityPicture : (attrs?.entityPicture ?? state.entityPicture)

    let newPlaybackState = diff?.s.flatMap { PlaybackState(rawValue: $0) } ?? state.playbackState

    // Some HA integrations (e.g. Spotify) briefly send media_position=0 in the first
    // diff when resuming from pause, before a follow-up diff corrects it to the actual
    // position. `??` only falls back on nil, so an explicit 0 would overwrite the paused
    // position and make the seek bar jump. Guard: when resuming from pause, discard a
    // position of 0 if the track appears unchanged and the old position was past the start.
    let rawPosition = attrs?.mediaPosition
    let isTitleUnchanged = attrs?.mediaTitle == nil || attrs?.mediaTitle == state.mediaTitle
    let isResumingFromPause = state.playbackState == .paused && newPlaybackState == .playing
    let resolvedPosition: Double?
    if isResumingFromPause, rawPosition == 0, (state.mediaPosition ?? 0) > 2, isTitleUnchanged {
        resolvedPosition = state.mediaPosition
    } else {
        resolvedPosition = rawPosition ?? state.mediaPosition
    }

    return MediaPlayerState(
        entityId: state.entityId,
        friendlyName: attrs?.friendlyName ?? state.friendlyName,
        playbackState: newPlaybackState,
        mediaTitle: attrs?.mediaTitle ?? state.mediaTitle,
        mediaArtist: attrs?.mediaArtist ?? state.mediaArtist,
        mediaAlbumName: attrs?.mediaAlbumName ?? state.mediaAlbumName,
        mediaAlbumArtist: attrs?.mediaAlbumArtist ?? state.mediaAlbumArtist,
        mediaContentType: attrs?.mediaContentType ?? state.mediaContentType,
        mediaSeriesTitle: attrs?.mediaSeriesTitle ?? state.mediaSeriesTitle,
        mediaSeason: attrs?.mediaSeason?.stringValue ?? state.mediaSeason,
        mediaEpisode: attrs?.mediaEpisode?.stringValue ?? state.mediaEpisode,
        mediaChannel: attrs?.mediaChannel ?? state.mediaChannel,
        appName: attrs?.appName ?? state.appName,
        appId: attrs?.appId ?? state.appId,
        entityPicture: resolvedPicture,
        mediaDuration: attrs?.mediaDuration ?? state.mediaDuration,
        mediaPosition: resolvedPosition,
        mediaPositionUpdatedAt: posDate,
        supportedFeaturesRaw: attrs?.supportedFeatures ?? state.supportedFeaturesRaw,
        shuffle: attrs?.shuffle ?? state.shuffle,
        repeatMode: attrs?.repeatMode.flatMap { RepeatMode(rawValue: $0) } ?? state.repeatMode,
        volume: attrs?.volumeLevel ?? state.volume,
        isMuted: attrs?.isMuted ?? state.isMuted
    )
}
