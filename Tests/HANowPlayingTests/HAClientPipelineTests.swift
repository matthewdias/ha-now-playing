import Testing
@testable import HANowPlaying
import Foundation

// Tests the full JSON → HAInboundMessage → entity routing pipeline via handleText.
// No network I/O: connect() is never called, so no WebSocket is opened.
@Suite("HAClient Pipeline", .serialized)
@MainActor
struct HAClientPipelineTests {

    let client = HomeAssistantClient()

    // MARK: - Add events

    @Test func addEventCreatesEntity() async {
        await client.handleText(subscribeEvent(adds: [
            "media_player.spotify": """
            {"s":"playing","a":{"friendly_name":"Spotify","media_title":"Karma Police",
             "media_artist":"Radiohead","supported_features":32},"lu":0}
            """
        ]), token: "t")
        let entity = client.entities["media_player.spotify"]
        #expect(entity?.friendlyName == "Spotify")
        #expect(entity?.mediaTitle == "Karma Police")
        #expect(entity?.playbackState == .playing)
        #expect(entity?.supportsNextTrack == true)
    }

    @Test func addEventIgnoresNonMediaPlayerEntities() async {
        await client.handleText(subscribeEvent(adds: [
            "light.living_room": #"{"s":"on","a":{},"lu":0}"#
        ]), token: "t")
        #expect(client.entities.isEmpty)
    }

    @Test func addEventCreatesMultipleEntities() async {
        await client.handleText(subscribeEvent(adds: [
            "media_player.a": #"{"s":"playing","a":{"friendly_name":"A"},"lu":0}"#,
            "media_player.b": #"{"s":"paused","a":{"friendly_name":"B"},"lu":0}"#
        ]), token: "t")
        #expect(client.entities.count == 2)
        #expect(client.entities["media_player.a"]?.playbackState == .playing)
        #expect(client.entities["media_player.b"]?.playbackState == .paused)
    }

    // MARK: - Change events

    @Test func changeEventUpdatesTitle() async {
        await seedEntity()
        await client.handleText(subscribeEvent(changes: [
            "media_player.test": #"{"+":{"a":{"media_title":"New Track"}}}"#
        ]), token: "t")
        #expect(client.entities["media_player.test"]?.mediaTitle == "New Track")
    }

    @Test func changeEventUpdatesPlaybackState() async {
        await seedEntity(state: "playing")
        await client.handleText(subscribeEvent(changes: [
            "media_player.test": #"{"+":{"s":"paused"}}"#
        ]), token: "t")
        #expect(client.entities["media_player.test"]?.playbackState == .paused)
    }

    @Test func changeEventPreservesUnchangedFields() async {
        await seedEntity()
        await client.handleText(subscribeEvent(changes: [
            "media_player.test": #"{"+":{"s":"paused"}}"#
        ]), token: "t")
        #expect(client.entities["media_player.test"]?.friendlyName == "Test Player")
        #expect(client.entities["media_player.test"]?.mediaTitle == "Original Track")
    }

    @Test func changeEventForUnknownEntityIsIgnored() async {
        await client.handleText(subscribeEvent(changes: [
            "media_player.ghost": #"{"+":{"s":"playing"}}"#
        ]), token: "t")
        #expect(client.entities["media_player.ghost"] == nil)
    }

    // MARK: - Remove events

    @Test func removeEventDeletesEntity() async {
        await seedEntity()
        await client.handleText(subscribeEvent(removes: ["media_player.test"]), token: "t")
        #expect(client.entities["media_player.test"] == nil)
    }

    @Test func removeEventIgnoresUnknownEntity() async {
        await seedEntity()
        await client.handleText(subscribeEvent(removes: ["media_player.ghost"]), token: "t")
        #expect(client.entities.count == 1)
    }

    // MARK: - Artwork heuristic (end-to-end)

    @Test func appIdChangeEndToEndClearsPicture() async {
        // Seed with Spotify playing and an entity_picture
        await client.handleText(subscribeEvent(adds: [
            "media_player.test": """
            {"s":"playing","a":{"app_id":"com.spotify.Spotify",
             "entity_picture":"/spotify.jpg","friendly_name":"Test"},"lu":0}
            """
        ]), token: "t")
        #expect(client.entities["media_player.test"]?.entityPicture == "/spotify.jpg")

        // App changes to Netflix — picture should be cleared
        await client.handleText(subscribeEvent(changes: [
            "media_player.test": #"{"+":{"a":{"app_id":"com.netflix.Netflix"}}}"#
        ]), token: "t")
        #expect(client.entities["media_player.test"]?.entityPicture == nil)
        #expect(client.entities["media_player.test"]?.appId == "com.netflix.Netflix")
    }

    // MARK: - Helpers

    func seedEntity(state: String = "playing") async {
        await client.handleText(subscribeEvent(adds: [
            "media_player.test": """
            {"s":"\(state)","a":{"friendly_name":"Test Player",
             "media_title":"Original Track","app_id":"com.spotify.Spotify"},"lu":0}
            """
        ]), token: "t")
    }

    func subscribeEvent(
        adds: [String: String] = [:],
        changes: [String: String] = [:],
        removes: [String] = []
    ) -> String {
        var parts: [String] = []
        if !adds.isEmpty {
            let inner = adds.map { #""\#($0.key)":\#($0.value)"# }.joined(separator: ",")
            parts.append(#""a":{\#(inner)}"#)
        }
        if !changes.isEmpty {
            let inner = changes.map { #""\#($0.key)":\#($0.value)"# }.joined(separator: ",")
            parts.append(#""c":{\#(inner)}"#)
        }
        if !removes.isEmpty {
            let inner = removes.map { #""\#($0)""# }.joined(separator: ",")
            parts.append(#""r":[\#(inner)]"#)
        }
        return #"{"type":"event","event":{\#(parts.joined(separator: ","))}}"#
    }
}
