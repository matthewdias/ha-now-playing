// swiftlint:disable force_unwrapping
import Testing
@testable import HANowPlaying
import Foundation

@Suite("EntityParsing")
struct EntityParsingTests {

    let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - buildEntityState

    @Test func buildEntityStateUsesAttributes() throws {
        let attrs = HAAttributes(
            friendlyName: "Spotify", mediaTitle: "Karma Police", mediaArtist: "Radiohead",
            mediaAlbumName: nil, mediaAlbumArtist: nil, mediaContentType: "music",
            mediaSeriesTitle: nil, mediaSeason: nil, mediaEpisode: nil, mediaChannel: nil,
            appName: nil, appId: "com.spotify.Spotify", entityPicture: "/api/media/art.jpg",
            mediaDuration: 263.0, mediaPosition: nil, mediaPositionUpdatedAt: nil,
            supportedFeatures: MediaPlayerEntityFeature([.nextTrack, .volumeSet, .volumeMute]).rawValue,
            volumeLevel: 0.6, isMuted: false,
            shuffle: true, repeatMode: "all"
        )
        let state = buildEntityState(entityId: "media_player.spotify", stateStr: "playing",
                                     attrs: attrs, using: formatter)
        #expect(state.entityId == "media_player.spotify")
        #expect(state.friendlyName == "Spotify")
        #expect(state.playbackState == .playing)
        #expect(state.mediaTitle == "Karma Police")
        #expect(state.mediaArtist == "Radiohead")
        #expect(state.mediaContentType == "music")
        #expect(state.appId == "com.spotify.Spotify")
        #expect(state.entityPicture == "/api/media/art.jpg")
        #expect(state.mediaDuration == 263.0)
        #expect(state.supportsNextTrack)
        #expect(state.supportsVolumeSet)
        #expect(state.supportsVolumeMute)
        #expect(state.volume == 0.6)
        #expect(state.shuffle == true)
        #expect(state.repeatMode == .all)
    }

    @Test func buildEntityStateFallsBackToEntityIdForFriendlyName() {
        let state = buildEntityState(entityId: "media_player.test", stateStr: "idle",
                                     attrs: nil, using: formatter)
        #expect(state.friendlyName == "media_player.test")
    }

    @Test func buildEntityStateUnknownPlaybackStateForUnrecognisedString() {
        let state = buildEntityState(entityId: "media_player.test", stateStr: "buffering",
                                     attrs: nil, using: formatter)
        #expect(state.playbackState == .unknown)
    }

    @Test func buildEntityStateParsesPositionUpdatedAtFromAttrs() {
        let dateStr = "2024-01-01T12:00:00.000Z"
        let expected = formatter.date(from: dateStr)!
        let attrs = HAAttributes(
            friendlyName: nil, mediaTitle: nil, mediaArtist: nil, mediaAlbumName: nil,
            mediaAlbumArtist: nil, mediaContentType: nil, mediaSeriesTitle: nil,
            mediaSeason: nil, mediaEpisode: nil, mediaChannel: nil, appName: nil, appId: nil,
            entityPicture: nil, mediaDuration: nil, mediaPosition: 45.0,
            mediaPositionUpdatedAt: dateStr, supportedFeatures: nil,
            volumeLevel: nil, isMuted: nil, shuffle: nil, repeatMode: nil
        )
        let state = buildEntityState(entityId: "media_player.test", stateStr: "playing",
                                     attrs: attrs, using: formatter)
        #expect(state.mediaPositionUpdatedAt == expected)
    }

    // MARK: - applyEntityChange: basic merging

    @Test func applyEntityChangeUpdatesTitle() throws {
        let base = makeBase()
        let change = try makeChange(json: #"{"+":{  "a":{"media_title":"New Title"}}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.mediaTitle == "New Title")
        #expect(result.mediaArtist == base.mediaArtist) // unchanged
    }

    @Test func applyEntityChangeUpdatesPlaybackState() throws {
        let base = makeBase(playbackState: .paused)
        let change = try makeChange(json: #"{"+":{"s":"playing"}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.playbackState == .playing)
    }

    @Test func applyEntityChangeRetainsUnchangedFields() throws {
        let base = makeBase()
        let change = try makeChange(json: #"{"+":{  "s":"paused"}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.mediaTitle == base.mediaTitle)
        #expect(result.entityPicture == base.entityPicture)
        #expect(result.appId == base.appId)
    }

    // MARK: - applyEntityChange: artwork heuristic

    @Test func applyEntityChangeRetainsPictureWhenAppIdUnchanged() throws {
        let base = makeBase(appId: "com.spotify.Spotify", entityPicture: "/old.jpg")
        let change = try makeChange(json: #"{"+":{  "a":{"app_id":"com.spotify.Spotify"}}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.entityPicture == "/old.jpg")
    }

    @Test func applyEntityChangeClearsPictureWhenAppIdChanges() throws {
        let base = makeBase(appId: "com.spotify.Spotify", entityPicture: "/spotify.jpg")
        let change = try makeChange(json: #"{"+":{  "a":{"app_id":"com.netflix.Netflix"}}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.entityPicture == nil)
        #expect(result.appId == "com.netflix.Netflix")
    }

    @Test func applyEntityChangeUsesNewPictureWhenAppIdChanges() throws {
        let base = makeBase(appId: "com.spotify.Spotify", entityPicture: "/spotify.jpg")
        let change = try makeChange(
            json: #"{"+":{  "a":{"app_id":"com.netflix.Netflix","entity_picture":"/netflix.jpg"}}}"#
        )
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.entityPicture == "/netflix.jpg")
        #expect(result.appId == "com.netflix.Netflix")
    }

    @Test func applyEntityChangeRetainsPictureWhenNoAppIdInDiff() throws {
        let base = makeBase(appId: "com.spotify.Spotify", entityPicture: "/art.jpg")
        // Diff only updates title, no appId key at all
        let change = try makeChange(json: #"{"+":{  "a":{"media_title":"Different Track"}}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.entityPicture == "/art.jpg")
    }

    // MARK: - applyEntityChange: resume position guard

    // Some HA integrations (e.g. Spotify) briefly send media_position=0 in the first
    // diff when resuming from pause, before a follow-up corrects it to the actual position.
    // applyEntityChange should discard the transient 0 and preserve the paused position.

    @Test func applyEntityChangePreservesPositionWhenResumedWithZero() throws {
        let base = makeBase(playbackState: .paused)  // paused at 30s
        let posJson = #"{"media_position":0,"media_position_updated_at":"2026-01-01T12:00:00.000Z"}"#
        let change = try makeChange(json: #"{"+":{  "s":"playing","a":\#(posJson)}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.mediaPosition == 30.0)
    }

    @Test func applyEntityChangeAcceptsZeroWhenTitleChanges() throws {
        let base = makeBase(playbackState: .paused)
        // swiftlint:disable:next line_length
        let change = try makeChange(json: #"{"+":{  "s":"playing","a":{"media_title":"New Song","media_position":0,"media_position_updated_at":"2026-01-01T12:00:00.000Z"}}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.mediaPosition == 0.0)
    }

    @Test func applyEntityChangeAcceptsZeroWhenOldPositionWasAlsoZero() throws {
        let base = MediaPlayerState(
            entityId: "media_player.test", friendlyName: "Test", playbackState: .paused,
            mediaTitle: "Track", mediaArtist: nil, mediaAlbumName: nil, mediaAlbumArtist: nil,
            mediaContentType: nil, mediaSeriesTitle: nil, mediaSeason: nil, mediaEpisode: nil,
            mediaChannel: nil, appName: nil, appId: nil, entityPicture: nil,
            mediaDuration: 200, mediaPosition: 0, mediaPositionUpdatedAt: nil,
            supportedFeaturesRaw: 0, shuffle: false, repeatMode: .off, volume: nil, isMuted: false
        )
        let posJson = #"{"media_position":0,"media_position_updated_at":"2026-01-01T12:00:00.000Z"}"#
        let change = try makeChange(json: #"{"+":{  "s":"playing","a":\#(posJson)}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.mediaPosition == 0.0)
    }

    @Test func applyEntityChangeAcceptsNonZeroPositionOnResume() throws {
        let base = makeBase(playbackState: .paused)
        let posJson = #"{"media_position":45,"media_position_updated_at":"2026-01-01T12:00:00.000Z"}"#
        let change = try makeChange(json: #"{"+":{  "s":"playing","a":\#(posJson)}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.mediaPosition == 45.0)
    }

    @Test func applyEntityChangeAcceptsZeroWhenAlreadyPlaying() throws {
        let base = makeBase(playbackState: .playing)
        let posJson = #"{"media_position":0,"media_position_updated_at":"2026-01-01T12:00:00.000Z"}"#
        let change = try makeChange(json: #"{"+":{  "a":\#(posJson)}}"#)
        let result = applyEntityChange(change, to: base, luDate: nil, using: formatter)
        #expect(result.mediaPosition == 0.0)
    }

    // MARK: - applyEntityChange: position date

    @Test func applyEntityChangePrefersPositionDateFromDiffAttrs() throws {
        let luDate = Date().addingTimeInterval(-100)
        let diffDateStr = "2024-06-01T10:00:00.000Z"
        let expected = formatter.date(from: diffDateStr)!
        let base = makeBase()
        let change = try makeChange(json: #"{"+":{  "a":{"media_position_updated_at":"\#(diffDateStr)"}}}"#)
        let result = applyEntityChange(change, to: base, luDate: luDate, using: formatter)
        #expect(result.mediaPositionUpdatedAt == expected)
    }

    @Test func applyEntityChangeFallsBackToLuDateForPosition() throws {
        let luDate = Date(timeIntervalSince1970: 1000)
        let base = makeBase()
        let change = try makeChange(json: #"{"+":{  "s":"playing"}}"#)
        let result = applyEntityChange(change, to: base, luDate: luDate, using: formatter)
        #expect(result.mediaPositionUpdatedAt == luDate)
    }

    // MARK: - Helpers

    func makeBase(
        appId: String? = "com.spotify.Spotify",
        entityPicture: String? = "/art.jpg",
        playbackState: PlaybackState = .playing
    ) -> MediaPlayerState {
        MediaPlayerState(
            entityId: "media_player.test",
            friendlyName: "Test Player",
            playbackState: playbackState,
            mediaTitle: "Original Title",
            mediaArtist: "Original Artist",
            mediaAlbumName: nil, mediaAlbumArtist: nil, mediaContentType: "music",
            mediaSeriesTitle: nil, mediaSeason: nil, mediaEpisode: nil, mediaChannel: nil,
            appName: nil, appId: appId, entityPicture: entityPicture,
            mediaDuration: 200.0, mediaPosition: 30.0, mediaPositionUpdatedAt: nil,
            supportedFeaturesRaw: 0, shuffle: false, repeatMode: .off, volume: 0.5, isMuted: false
        )
    }

    func makeChange(json: String) throws -> HAEntityChange {
        try JSONDecoder().decode(HAEntityChange.self, from: json.data(using: .utf8)!)
    }
}
