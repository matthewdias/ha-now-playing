import Testing
@testable import HANowPlaying
import MediaPlayer
import Foundation
import AppKit

// MPNowPlayingInfoCenter.default() and MPRemoteCommandCenter.shared() are singletons,
// so tests must run serially and reset state between runs.
@Suite("NowPlayingController", .serialized)
@MainActor
struct NowPlayingControllerTests {

    let controller = NowPlayingController()
    let client = MockHAClient()
    let infoCenter = MPNowPlayingInfoCenter.default()
    let commandCenter = MPRemoteCommandCenter.shared()

    init() {
        infoCenter.nowPlayingInfo = nil
    }

    // MARK: - Fixtures

    func makeState(
        entityId: String = "media_player.test",
        friendlyName: String = "Test Player",
        playbackState: PlaybackState = .playing,
        mediaTitle: String? = "Track",
        mediaArtist: String? = "Artist",
        mediaAlbumName: String? = nil,
        mediaAlbumArtist: String? = nil,
        mediaContentType: String? = "music",
        mediaSeriesTitle: String? = nil,
        mediaSeason: String? = nil,
        mediaEpisode: String? = nil,
        mediaChannel: String? = nil,
        appName: String? = nil,
        appId: String? = nil,
        entityPicture: String? = nil,
        mediaDuration: Double? = 180,
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
            mediaAlbumArtist: mediaAlbumArtist,
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

    // MARK: - nowPlayingInfo population

    @Test func updateSetsTitle() {
        controller.update(state: makeState(mediaTitle: "Karma Police"), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String == "Karma Police")
    }

    @Test func updateFallsBackToFriendlyNameWhenNoTitle() {
        controller.update(state: makeState(friendlyName: "Living Room", mediaTitle: nil), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String == "Living Room")
    }

    @Test func updateSetsArtist() {
        controller.update(state: makeState(mediaArtist: "Radiohead"), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyArtist] as? String == "Radiohead")
    }

    @Test func updateSetsAlbum() {
        controller.update(state: makeState(mediaAlbumName: "OK Computer"), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyAlbumTitle] as? String == "OK Computer")
    }

    @Test func updateSetsPlaybackRateOneWhenPlaying() {
        controller.update(state: makeState(playbackState: .playing), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1.0)
    }

    @Test func updateSetsPlaybackRateZeroWhenPaused() {
        controller.update(state: makeState(playbackState: .paused), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 0.0)
    }

    @Test func updateSetsDuration() {
        controller.update(state: makeState(mediaDuration: 240), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] as? Double == 240)
    }

    @Test func updateSetsLiveStreamFlag() {
        controller.update(state: makeState(mediaContentType: "channel"), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyIsLiveStream] as? Bool == true)
    }

    @Test func updateOmitsDurationForLiveStream() {
        controller.update(state: makeState(mediaContentType: "channel", mediaDuration: 999), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] == nil)
    }

    // MARK: - Artwork preservation

    @Test func artworkPreservedAcrossMetadataUpdates() {
        let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 100, height: 100)) { _ in NSImage() }
        infoCenter.nowPlayingInfo = [MPMediaItemPropertyArtwork: artwork]

        controller.update(state: makeState(entityPicture: "/img.jpg"), client: client)
        controller.update(state: makeState(entityPicture: "/img.jpg"), client: client)

        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyArtwork] != nil)
    }

    @Test func artworkClearedWhenEntityBecomesInactive() {
        let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 100, height: 100)) { _ in NSImage() }
        infoCenter.nowPlayingInfo = [MPMediaItemPropertyArtwork: artwork]

        controller.update(state: makeState(), client: client)
        controller.update(state: nil, client: client)

        #expect(infoCenter.nowPlayingInfo == nil)
    }

    // MARK: - Clear on inactive state

    @Test func updateWithNilStateClearsInfoCenter() {
        controller.update(state: makeState(), client: client)
        controller.update(state: nil, client: client)
        #expect(infoCenter.nowPlayingInfo == nil)
    }

    @Test func updateWithIdleStateClearsInfoCenter() {
        controller.update(state: makeState(), client: client)
        controller.update(state: makeState(playbackState: .idle), client: client)
        #expect(infoCenter.nowPlayingInfo == nil)
    }

    @Test func updateWithOffStateClearsInfoCenter() {
        controller.update(state: makeState(), client: client)
        controller.update(state: makeState(playbackState: .off), client: client)
        #expect(infoCenter.nowPlayingInfo == nil)
    }

    // MARK: - Media type mapping

    @Test func mediaTypeMusicMapsToMusic() {
        controller.update(state: makeState(mediaContentType: "music"), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyMediaType] as? UInt == MPMediaType.music.rawValue)
    }

    @Test func mediaTypePodcastMapsToPodcast() {
        controller.update(state: makeState(mediaContentType: "podcast"), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyMediaType] as? UInt == MPMediaType.podcast.rawValue)
    }

    @Test func mediaTypeTvShowMapsToTvShow() {
        controller.update(state: makeState(mediaContentType: "tvshow"), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyMediaType] as? UInt == MPMediaType.tvShow.rawValue)
    }

    @Test func mediaTypeEpisodeMapsToTvShow() {
        controller.update(state: makeState(mediaContentType: "episode"), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyMediaType] as? UInt == MPMediaType.tvShow.rawValue)
    }

    @Test func mediaTypeMovieMapsToMovie() {
        controller.update(state: makeState(mediaContentType: "movie"), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyMediaType] as? UInt == MPMediaType.movie.rawValue)
    }

    @Test func mediaTypeMusicVideoMapsMusicVideo() {
        controller.update(state: makeState(mediaContentType: "musicvideo"), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyMediaType] as? UInt == MPMediaType.musicVideo.rawValue)
    }

    @Test func mediaTypeNilDefaultsToMusic() {
        controller.update(state: makeState(mediaContentType: nil), client: client)
        #expect(infoCenter.nowPlayingInfo?[MPMediaItemPropertyMediaType] as? UInt == MPMediaType.music.rawValue)
    }

    // MARK: - Artwork handler thread safety

    // MPMediaItemArtwork's request handler is invoked by MediaPlayer on its private
    // accessQueue (a non-main thread). Under Swift 6, a closure built inside @MainActor
    // code is inferred @MainActor-isolated; calling it off-main crashes with
    // dispatch_assert_queue_fail (swiftlang/swift#75453). makeArtwork(from:) is
    // nonisolated so its handler carries no main-actor isolation and is safe to call
    // from any thread.
    @Test func artworkHandlerIsCallableOffMainThread() async {
        let image = NSImage(size: CGSize(width: 100, height: 100))
        let artwork = NowPlayingController.makeArtwork(from: image)

        let result: NSImage? = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: artwork.image(at: CGSize(width: 100, height: 100)))
            }
        }

        #expect(result != nil)
    }

    // MARK: - Command enable/disable

    @Test func nextTrackCommandEnabledWhenSupported() {
        controller.update(state: makeState(features: .nextTrack), client: client)
        #expect(commandCenter.nextTrackCommand.isEnabled == true)
    }

    @Test func nextTrackCommandDisabledWhenNotSupported() {
        controller.update(state: makeState(features: []), client: client)
        #expect(commandCenter.nextTrackCommand.isEnabled == false)
    }

    @Test func previousTrackCommandEnabledWhenSupported() {
        controller.update(state: makeState(features: .previousTrack), client: client)
        #expect(commandCenter.previousTrackCommand.isEnabled == true)
    }

    @Test func seekCommandDisabledForLiveStream() {
        controller.update(state: makeState(mediaContentType: "channel", features: .seek), client: client)
        #expect(commandCenter.changePlaybackPositionCommand.isEnabled == false)
    }

    @Test func seekCommandEnabledWhenSupportedAndNotLive() {
        controller.update(state: makeState(mediaContentType: "music", features: .seek), client: client)
        #expect(commandCenter.changePlaybackPositionCommand.isEnabled == true)
    }

    @Test func shuffleCommandEnabledWhenSupported() {
        controller.update(state: makeState(features: .shuffle), client: client)
        #expect(commandCenter.changeShuffleModeCommand.isEnabled == true)
    }

    @Test func repeatCommandEnabledWhenSupported() {
        controller.update(state: makeState(features: .repeat), client: client)
        #expect(commandCenter.changeRepeatModeCommand.isEnabled == true)
    }
}
