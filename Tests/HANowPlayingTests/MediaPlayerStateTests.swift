// swiftlint:disable force_unwrapping
import Testing
@testable import HANowPlaying
import Foundation

@Suite("MediaPlayerState")
struct MediaPlayerStateTests {

    // MARK: - Fixture

    func makeState(
        entityId: String = "media_player.test",
        friendlyName: String = "Test Player",
        playbackState: PlaybackState = .playing,
        mediaTitle: String? = nil,
        mediaArtist: String? = nil,
        mediaAlbumName: String? = nil,
        mediaContentType: String? = nil,
        mediaSeriesTitle: String? = nil,
        mediaSeason: String? = nil,
        mediaEpisode: String? = nil,
        mediaChannel: String? = nil,
        appName: String? = nil,
        appId: String? = nil,
        entityPicture: String? = nil,
        mediaDuration: Double? = nil,
        mediaPosition: Double? = nil,
        mediaPositionUpdatedAt: Date? = nil,
        features: MediaPlayerEntityFeature = [],
        shuffle: Bool = false,
        repeatMode: RepeatMode = .off,
        volume: Double? = nil,
        isMuted: Bool = false
    ) -> MediaPlayerState {
        MediaPlayerState(
            entityId: entityId,
            friendlyName: friendlyName,
            playbackState: playbackState,
            mediaTitle: mediaTitle,
            mediaArtist: mediaArtist,
            mediaAlbumName: mediaAlbumName,
            mediaAlbumArtist: nil,
            mediaContentType: mediaContentType,
            mediaSeriesTitle: mediaSeriesTitle,
            mediaSeason: mediaSeason,
            mediaEpisode: mediaEpisode,
            mediaChannel: mediaChannel,
            appName: appName,
            appId: appId,
            entityPicture: entityPicture,
            mediaDuration: mediaDuration,
            mediaPosition: mediaPosition,
            mediaPositionUpdatedAt: mediaPositionUpdatedAt,
            supportedFeaturesRaw: features.rawValue,
            shuffle: shuffle,
            repeatMode: repeatMode,
            volume: volume,
            isMuted: isMuted
        )
    }

    // MARK: - primaryTitle

    @Test func primaryTitleUsesMediaTitle() {
        let state = makeState(mediaTitle: "Karma Police")
        #expect(state.primaryTitle == "Karma Police")
    }

    @Test func primaryTitleFallsBackToFriendlyName() {
        let state = makeState(friendlyName: "Living Room Speaker", mediaTitle: nil)
        #expect(state.primaryTitle == "Living Room Speaker")
    }

    // MARK: - secondaryTitle

    @Test func secondaryTitleForMusicIsArtist() {
        let state = makeState(mediaArtist: "Radiohead", mediaContentType: "music")
        #expect(state.secondaryTitle == "Radiohead")
    }

    @Test func secondaryTitleForNilContentTypeIsArtist() {
        let state = makeState(mediaArtist: "Radiohead", mediaContentType: nil)
        #expect(state.secondaryTitle == "Radiohead")
    }

    @Test func secondaryTitleForTVShowPrefersSeriesTitle() {
        let state = makeState(mediaContentType: "tvshow", mediaSeriesTitle: "Breaking Bad", appName: "Netflix")
        #expect(state.secondaryTitle == "Breaking Bad")
    }

    @Test func secondaryTitleForTVShowFallsBackToAppName() {
        let state = makeState(mediaContentType: "tvshow", mediaSeriesTitle: nil, appName: "Netflix")
        #expect(state.secondaryTitle == "Netflix")
    }

    @Test func secondaryTitleForEpisodeIsSeriesTitle() {
        let state = makeState(mediaContentType: "episode", mediaSeriesTitle: "Fargo")
        #expect(state.secondaryTitle == "Fargo")
    }

    @Test func secondaryTitleForChannelIsChannelName() {
        let state = makeState(mediaContentType: "channel", mediaChannel: "BBC One")
        #expect(state.secondaryTitle == "BBC One")
    }

    @Test func secondaryTitleForChannelFallsBackToAppName() {
        let state = makeState(mediaContentType: "channel", mediaChannel: nil, appName: "Plex")
        #expect(state.secondaryTitle == "Plex")
    }

    @Test func secondaryTitleForMovieIsAppName() {
        let state = makeState(mediaContentType: "movie", appName: "Netflix")
        #expect(state.secondaryTitle == "Netflix")
    }

    @Test func secondaryTitleForMovieNilWhenNoAppName() {
        let state = makeState(mediaContentType: "movie", appName: nil)
        #expect(state.secondaryTitle == nil)
    }

    // MARK: - tertiaryTitle

    @Test func tertiaryTitleForMusicIsAlbum() {
        let state = makeState(mediaAlbumName: "OK Computer", mediaContentType: "music")
        #expect(state.tertiaryTitle == "OK Computer")
    }

    @Test func tertiaryTitleForNilContentTypeIsAlbum() {
        let state = makeState(mediaAlbumName: "OK Computer", mediaContentType: nil)
        #expect(state.tertiaryTitle == "OK Computer")
    }

    @Test func tertiaryTitleNilWhenNoAlbum() {
        let state = makeState(mediaAlbumName: nil, mediaContentType: "music")
        #expect(state.tertiaryTitle == nil)
    }

    @Test func tertiaryTitleForTVShowFormatsSeasonAndEpisode() {
        let state = makeState(mediaContentType: "tvshow", mediaSeason: "1", mediaEpisode: "3")
        #expect(state.tertiaryTitle == "S1E3")
    }

    @Test func tertiaryTitleForTVShowSeasonOnly() {
        let state = makeState(mediaContentType: "tvshow", mediaSeason: "2", mediaEpisode: nil)
        #expect(state.tertiaryTitle == "S2")
    }

    @Test func tertiaryTitleForTVShowEpisodeOnly() {
        let state = makeState(mediaContentType: "tvshow", mediaSeason: nil, mediaEpisode: "5")
        #expect(state.tertiaryTitle == "E5")
    }

    @Test func tertiaryTitleForTVShowNilWhenNeitherSeasonNorEpisode() {
        let state = makeState(mediaContentType: "tvshow")
        #expect(state.tertiaryTitle == nil)
    }

    @Test func tertiaryTitleNilForChannel() {
        let state = makeState(mediaContentType: "channel")
        #expect(state.tertiaryTitle == nil)
    }

    @Test func tertiaryTitleNilForMovie() {
        let state = makeState(mediaContentType: "movie")
        #expect(state.tertiaryTitle == nil)
    }

    // MARK: - Capability flags

    @Test(arguments: [
        (MediaPlayerEntityFeature.seek, { @Sendable (s: MediaPlayerState) in s.supportsSeek }),
        (MediaPlayerEntityFeature.volumeSet, { @Sendable (s: MediaPlayerState) in s.supportsVolumeSet }),
        (MediaPlayerEntityFeature.volumeMute, { @Sendable (s: MediaPlayerState) in s.supportsVolumeMute }),
        (MediaPlayerEntityFeature.previousTrack, { @Sendable (s: MediaPlayerState) in s.supportsPreviousTrack }),
        (MediaPlayerEntityFeature.nextTrack, { @Sendable (s: MediaPlayerState) in s.supportsNextTrack }),
        (MediaPlayerEntityFeature.shuffle, { @Sendable (s: MediaPlayerState) in s.supportsShuffle }),
        (MediaPlayerEntityFeature.repeat, { @Sendable (s: MediaPlayerState) in s.supportsRepeat })
    ] as [(MediaPlayerEntityFeature, @Sendable (MediaPlayerState) -> Bool)])
    func capabilityFlagSetWhenBitPresent(feature: MediaPlayerEntityFeature, flag: @Sendable (MediaPlayerState) -> Bool) {
        #expect(flag(makeState(features: feature)) == true)
    }

    @Test(arguments: [
        (MediaPlayerEntityFeature.seek, { @Sendable (s: MediaPlayerState) in s.supportsSeek }),
        (MediaPlayerEntityFeature.volumeSet, { @Sendable (s: MediaPlayerState) in s.supportsVolumeSet }),
        (MediaPlayerEntityFeature.volumeMute, { @Sendable (s: MediaPlayerState) in s.supportsVolumeMute }),
        (MediaPlayerEntityFeature.previousTrack, { @Sendable (s: MediaPlayerState) in s.supportsPreviousTrack }),
        (MediaPlayerEntityFeature.nextTrack, { @Sendable (s: MediaPlayerState) in s.supportsNextTrack }),
        (MediaPlayerEntityFeature.shuffle, { @Sendable (s: MediaPlayerState) in s.supportsShuffle }),
        (MediaPlayerEntityFeature.repeat, { @Sendable (s: MediaPlayerState) in s.supportsRepeat })
    ] as [(MediaPlayerEntityFeature, @Sendable (MediaPlayerState) -> Bool)])
    func capabilityFlagClearWhenBitAbsent(feature: MediaPlayerEntityFeature, flag: @Sendable (MediaPlayerState) -> Bool) {
        #expect(flag(makeState(features: [])) == false)
    }

    @Test func multipleCapabilityFlagsCoexist() {
        let state = makeState(features: [.seek, .volumeSet, .shuffle])
        #expect(state.supportsSeek)
        #expect(state.supportsVolumeSet)
        #expect(state.supportsShuffle)
        #expect(!state.supportsVolumeMute)
        #expect(!state.supportsNextTrack)
    }

    // MARK: - isLiveStream

    @Test(arguments: [
        ("channel", true),
        ("url", true),
        ("music", false),
        ("tvshow", false)
    ] as [(String, Bool)])
    func isLiveStream(contentType: String, expected: Bool) {
        #expect(makeState(mediaContentType: contentType).isLiveStream == expected)
    }

    @Test func isLiveStreamFalseForNilContentType() {
        #expect(makeState(mediaContentType: nil).isLiveStream == false)
    }

    // MARK: - interpolatedPosition

    @Test func interpolatedPositionAdvancesWhenPlaying() {
        let updatedAt = Date().addingTimeInterval(-5)
        let state = makeState(playbackState: .playing, mediaPosition: 10.0, mediaPositionUpdatedAt: updatedAt)
        let pos = state.interpolatedPosition
        #expect(pos != nil)
        #expect(pos! >= 15.0 && pos! < 16.0)
    }

    @Test func interpolatedPositionStaysFixedWhenPaused() {
        let updatedAt = Date().addingTimeInterval(-10)
        let state = makeState(playbackState: .paused, mediaPosition: 30.0, mediaPositionUpdatedAt: updatedAt)
        #expect(state.interpolatedPosition == 30.0)
    }

    @Test func interpolatedPositionNilWithNoPosition() {
        let state = makeState(mediaPosition: nil, mediaPositionUpdatedAt: nil)
        #expect(state.interpolatedPosition == nil)
    }

    @Test func interpolatedPositionNilWithPositionButNoDate() {
        let state = makeState(mediaPosition: 10.0, mediaPositionUpdatedAt: nil)
        #expect(state.interpolatedPosition == nil)
    }

    @Test func interpolatedPositionIsZeroWhenUpdatedAtIsInFuture() {
        let updatedAt = Date().addingTimeInterval(5)
        let state = makeState(playbackState: .playing, mediaPosition: 0, mediaPositionUpdatedAt: updatedAt)
        #expect((state.interpolatedPosition ?? -1) >= 0)
    }

    // MARK: - Equality

    @Test func equalityReturnsFalseWhenMediaDurationChanges() {
        let a = makeState(mediaDuration: 180)
        let b = makeState(mediaDuration: 240)
        #expect(a != b)
    }

    @Test func equalityReturnsFalseWhenSupportedFeaturesChange() {
        let a = makeState(features: [])
        let b = makeState(features: .shuffle)
        #expect(a != b)
    }

    // MARK: - RepeatMode

    @Test func repeatModeCyclesCorrectly() {
        #expect(RepeatMode.off.next == .all)
        #expect(RepeatMode.all.next == .one)
        #expect(RepeatMode.one.next == .off)
    }
}
