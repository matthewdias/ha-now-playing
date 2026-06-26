// swiftlint:disable force_unwrapping
import Testing
@testable import HANowPlaying
import Foundation

@Suite("ActiveEntitySelector", .serialized)
@MainActor
struct ActiveEntitySelectorTests {

    let selector: ActiveEntitySelector

    init() {
        selector = ActiveEntitySelector(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    // MARK: - Fixtures

    func makeState(
        entityId: String,
        playbackState: PlaybackState,
        lastUpdated: Date = .distantPast
    ) -> MediaPlayerState {
        MediaPlayerState(
            entityId: entityId,
            friendlyName: entityId,
            playbackState: playbackState,
            mediaTitle: nil, mediaArtist: nil, mediaAlbumName: nil, mediaAlbumArtist: nil,
            mediaContentType: nil, mediaSeriesTitle: nil, mediaSeason: nil, mediaEpisode: nil,
            mediaChannel: nil, appName: nil, appId: nil, entityPicture: nil,
            mediaDuration: nil, mediaPosition: nil, mediaPositionUpdatedAt: lastUpdated,
            supportedFeaturesRaw: 0, shuffle: false, repeatMode: .off, volume: nil, isMuted: false
        )
    }

    // MARK: - Auto mode: selection

    @Test func autoSelectsSinglePlayingEntity() {
        let entities = ["media_player.a": makeState(entityId: "media_player.a", playbackState: .playing)]
        selector.update(entities: entities)
        #expect(selector.activeEntityId == "media_player.a")
    }

    @Test func autoSelectsSinglePausedEntityWhenNothingPlaying() {
        let entities = ["media_player.a": makeState(entityId: "media_player.a", playbackState: .paused)]
        selector.update(entities: entities)
        #expect(selector.activeEntityId == "media_player.a")
    }

    @Test func autoReturnsNilWhenNoActiveEntities() {
        let entities = ["media_player.a": makeState(entityId: "media_player.a", playbackState: .idle)]
        selector.update(entities: entities)
        #expect(selector.activeEntityId == nil)
    }

    @Test func autoPrefersPlayingOverPaused() {
        let entities = [
            "media_player.a": makeState(entityId: "media_player.a", playbackState: .paused),
            "media_player.b": makeState(entityId: "media_player.b", playbackState: .playing)
        ]
        selector.update(entities: entities)
        #expect(selector.activeEntityId == "media_player.b")
    }

    @Test func autoPicksMostRecentlyActiveWhenMultiplePlaying() {
        // First update: a starts playing
        selector.update(entities: [
            "media_player.a": makeState(entityId: "media_player.a", playbackState: .playing)
        ])
        #expect(selector.activeEntityId == "media_player.a")

        // Second update: b also starts playing — b is newer so should win
        selector.update(entities: [
            "media_player.a": makeState(entityId: "media_player.a", playbackState: .playing),
            "media_player.b": makeState(entityId: "media_player.b", playbackState: .playing)
        ])
        #expect(selector.activeEntityId == "media_player.b")
    }

    @Test func autoStaysOnCurrentWhenItRemainsPlaying() {
        selector.update(entities: [
            "media_player.a": makeState(entityId: "media_player.a", playbackState: .playing)
        ])
        selector.update(entities: [
            "media_player.a": makeState(entityId: "media_player.a", playbackState: .playing)
        ])
        #expect(selector.activeEntityId == "media_player.a")
    }

    @Test func autoReturnsNilWhenEntitiesDictIsEmpty() {
        selector.update(entities: [:])
        #expect(selector.activeEntityId == nil)
    }

    // MARK: - Manual mode

    @Test func pinSelectsSpecificEntity() {
        selector.pin(entityId: "media_player.b")
        let entities = [
            "media_player.a": makeState(entityId: "media_player.a", playbackState: .playing),
            "media_player.b": makeState(entityId: "media_player.b", playbackState: .paused)
        ]
        selector.update(entities: entities)
        #expect(selector.activeEntityId == "media_player.b")
    }

    @Test func pinnedEntityAbsentFromUpdateReturnsNil() {
        selector.pin(entityId: "media_player.b")
        let entities = ["media_player.a": makeState(entityId: "media_player.a", playbackState: .playing)]
        selector.update(entities: entities)
        #expect(selector.activeEntityId == nil)
    }

    @Test func pinNilReturnsToAutoMode() {
        selector.pin(entityId: "media_player.b")
        selector.pin(entityId: nil)
        #expect(selector.isPinned == false)
        let entities = ["media_player.a": makeState(entityId: "media_player.a", playbackState: .playing)]
        selector.update(entities: entities)
        #expect(selector.activeEntityId == "media_player.a")
    }

    @Test func isPinnedReflectsMode() {
        #expect(selector.isPinned == false)
        selector.pin(entityId: "media_player.a")
        #expect(selector.isPinned == true)
        selector.pin(entityId: nil)
        #expect(selector.isPinned == false)
    }
}
