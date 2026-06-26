import Foundation
import Observation

/// Central state object wiring HA client → entity selector → Now Playing controller.
@Observable
@MainActor
final class AppState {
    let client: any HAClient
    let selector = ActiveEntitySelector()
    private let nowPlayingController = NowPlayingController()
    private let credentials: any CredentialStore

    var isConfigured = false
    var hiddenEntityIds: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "hidden_entity_ids") ?? []
        return Set(saved)
    }()

    init(credentials: any CredentialStore = defaultCredentials, client: (any HAClient)? = nil) {
        self.credentials = credentials
        self.client = client ?? HomeAssistantClient()
        nowPlayingController.setUp(client: self.client)
        startEntityObservation()
        loadAndConnect()
    }

    func loadCredentials() -> (url: String, token: String) {
        (credentials.load(key: "ha_url") ?? "", credentials.load(key: "ha_token") ?? "")
    }

    // MARK: - Public API

    var activeEntity: MediaPlayerState? {
        guard let id = selector.activeEntityId else { return nil }
        return client.entities[id]
    }

    var sortedEntities: [MediaPlayerState] {
        client.entities.values
            .filter { !hiddenEntityIds.contains($0.entityId) }
            .sorted { $0.friendlyName < $1.friendlyName }
    }

    var allEntities: [MediaPlayerState] {
        client.entities.values.sorted { $0.friendlyName < $1.friendlyName }
    }

    var connectionState: HAConnectionState { client.connectionState }

    func artworkRequest(for path: String) -> URLRequest? { client.artworkRequest(for: path) }

    func disconnect() {
        client.disconnect()
        credentials.delete(key: "ha_url")
        credentials.delete(key: "ha_token")
        isConfigured = false
    }

    func setHidden(_ entityId: String, hidden: Bool) {
        if hidden {
            hiddenEntityIds.insert(entityId)
        } else {
            hiddenEntityIds.remove(entityId)
        }
        UserDefaults.standard.set(Array(hiddenEntityIds), forKey: "hidden_entity_ids")
        selector.update(entities: client.entities.filter { !hiddenEntityIds.contains($0.key) })
    }

    @discardableResult
    func connect(haURL: String, token: String) -> Bool {
        guard let url = URL(string: haURL) else { return false }
        credentials.save(key: "ha_url", value: haURL)
        credentials.save(key: "ha_token", value: token)
        isConfigured = true
        client.connect(baseURL: url, token: token)
        return true
    }

    func sendCommand(_ service: String, data: [String: ServiceValue] = [:]) {
        guard let entityId = selector.activeEntityId else { return }
        client.callService(domain: "media_player", service: service, entityId: entityId, data: data)
    }

    // MARK: - Private

    private var syncTask: Task<Void, Never>?

    private func startEntityObservation() {
        syncNowPlaying()
        observeNext()
    }

    private func observeNext() {
        // withObservationTracking fires onChange exactly once then disarms.
        // Reading the properties here registers them as tracked; the onChange
        // Task re-arms observation so it stays live across changes.
        withObservationTracking {
            _ = client.entities
            _ = selector.activeEntityId
        } onChange: { [weak self] in
            // onChange fires on an arbitrary queue — dispatch back to MainActor.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scheduleSyncNowPlaying()
                self.observeNext()
            }
        }
    }

    // Debounce rapid entity updates (e.g. position ticks) before pushing to
    // MPNowPlayingInfoCenter, which can crash if called in quick succession.
    private func scheduleSyncNowPlaying() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            syncNowPlaying()
        }
    }

    private func syncNowPlaying() {
        let entities = client.entities
        let visible = entities.filter { !hiddenEntityIds.contains($0.key) }
        selector.update(entities: visible)
        let active = selector.activeEntityId.flatMap { entities[$0] }
        nowPlayingController.update(state: active, client: client)
    }

    private func loadAndConnect() {
        guard let url   = credentials.load(key: "ha_url"),
              let token = credentials.load(key: "ha_token") else { return }
        isConfigured = true
        guard let baseURL = URL(string: url) else { return }
        client.connect(baseURL: baseURL, token: token)
    }
}
