import Foundation
@testable import HANowPlaying

@Observable
@MainActor
final class MockHAClient: HAClient {
    var entities: [String: MediaPlayerState] = [:]
    var connectionState: HAConnectionState = .disconnected

    private(set) var connectCalled = false
    private(set) var disconnectCalled = false
    private(set) var lastConnectURL: URL?

    func connect(baseURL: URL, token: String) {
        connectCalled = true
        lastConnectURL = baseURL
        connectionState = .connecting
    }

    func disconnect() {
        disconnectCalled = true
        connectionState = .disconnected
    }

    func callService(domain: String, service: String, entityId: String, data: [String: ServiceValue]) {}

    func artworkRequest(for entityPicture: String) -> URLRequest? { nil }
}
