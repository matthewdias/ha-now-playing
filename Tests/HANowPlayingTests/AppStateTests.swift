import Testing
import Foundation
@testable import HANowPlaying

@Suite("AppState", .serialized)
@MainActor
struct AppStateTests {

    init() {
        UserDefaults.standard.removeObject(forKey: "hidden_entity_ids")
    }

    // swiftlint:disable large_tuple
    private func makeStore(url: String? = nil, token: String? = nil)
        -> (AppState, UserDefaultsCredentialStore, MockHAClient) {
        // swiftlint:enable large_tuple
        let suite = UserDefaults(suiteName: UUID().uuidString) ?? .standard
        let creds = UserDefaultsCredentialStore(defaults: suite)
        if let url { creds.save(key: "ha_url", value: url) }
        if let token { creds.save(key: "ha_token", value: token) }
        let client = MockHAClient()
        let state = AppState(credentials: creds, client: client)
        return (state, creds, client)
    }

    // MARK: - loadCredentials

    @Test func loadCredentialsReturnsEmptyStringsWhenNoneStored() {
        let (state, _, _) = makeStore()
        let creds = state.loadCredentials()
        #expect(creds.url.isEmpty)
        #expect(creds.token.isEmpty)
    }

    @Test func loadCredentialsReturnsStoredValues() {
        let (state, _, _) = makeStore(url: "http://homeassistant.local:8123", token: "abc123")
        let creds = state.loadCredentials()
        #expect(creds.url == "http://homeassistant.local:8123")
        #expect(creds.token == "abc123")
    }

    // MARK: - init

    @Test func initWithStoredCredentialsSetsConfiguredAndConnects() {
        let (state, _, client) = makeStore(url: "http://homeassistant.local:8123", token: "tok")
        #expect(state.isConfigured == true)
        #expect(client.connectCalled == true)
    }

    @Test func initWithoutStoredCredentialsLeavesNotConfiguredAndDoesNotConnect() {
        let (state, _, client) = makeStore()
        #expect(state.isConfigured == false)
        #expect(client.connectCalled == false)
    }

    // MARK: - connect

    @Test func connectSavesCredentialsAndSetsConfigured() {
        let (state, creds, _) = makeStore()
        state.connect(haURL: "http://homeassistant.local:8123", token: "mytoken")
        #expect(state.isConfigured == true)
        #expect(creds.load(key: "ha_url") == "http://homeassistant.local:8123")
        #expect(creds.load(key: "ha_token") == "mytoken")
    }

    @Test func connectCallsClientConnect() {
        let (state, _, client) = makeStore()
        state.connect(haURL: "http://homeassistant.local:8123", token: "mytoken")
        #expect(client.connectCalled == true)
        #expect(client.lastConnectURL == URL(string: "http://homeassistant.local:8123"))
    }

    @Test func connectReturnsTrueForValidURL() {
        let (state, _, _) = makeStore()
        let result = state.connect(haURL: "http://homeassistant.local:8123", token: "tok")
        #expect(result == true)
    }

    @Test func connectReturnsFalseForInvalidURL() {
        let (state, _, _) = makeStore()
        let result = state.connect(haURL: "", token: "tok")
        #expect(result == false)
    }

    @Test func connectWithInvalidURLDoesNotSetConfigured() {
        let (state, _, client) = makeStore()
        state.connect(haURL: "", token: "mytoken")
        #expect(state.isConfigured == false)
        #expect(client.connectCalled == false)
    }

    // MARK: - disconnect

    @Test func disconnectClearsCredentialsAndIsConfigured() {
        let (state, creds, _) = makeStore(url: "http://homeassistant.local:8123", token: "mytoken")
        state.disconnect()
        #expect(state.isConfigured == false)
        #expect(creds.load(key: "ha_url") == nil)
        #expect(creds.load(key: "ha_token") == nil)
    }

    @Test func disconnectCallsClientDisconnect() {
        let (state, _, client) = makeStore()
        state.disconnect()
        #expect(client.disconnectCalled == true)
    }

    // MARK: - setHidden

    @Test func setHiddenAddsEntityToHiddenSet() {
        let (state, _, _) = makeStore()
        state.setHidden("media_player.tv", hidden: true)
        #expect(state.hiddenEntityIds.contains("media_player.tv"))
    }

    @Test func setHiddenFalseRemovesEntityFromHiddenSet() {
        let (state, _, _) = makeStore()
        state.setHidden("media_player.tv", hidden: true)
        state.setHidden("media_player.tv", hidden: false)
        #expect(!state.hiddenEntityIds.contains("media_player.tv"))
    }

    @Test func setHiddenDoesNotAffectOtherEntities() {
        let (state, _, _) = makeStore()
        state.setHidden("media_player.tv", hidden: true)
        state.setHidden("media_player.speaker", hidden: true)
        state.setHidden("media_player.tv", hidden: false)
        #expect(!state.hiddenEntityIds.contains("media_player.tv"))
        #expect(state.hiddenEntityIds.contains("media_player.speaker"))
    }
}
