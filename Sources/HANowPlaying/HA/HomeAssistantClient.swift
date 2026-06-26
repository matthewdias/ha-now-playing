import Foundation
import Observation
import Network
import OSLog

private enum HAClientConstants {
    static let pingInterval: Double = 30
    static let pingTimeout: Double = 10
    static let maxReconnectDelay: Double = 30
}

@MainActor
protocol HAClient: AnyObject, Observable {
    var entities: [String: MediaPlayerState] { get }
    var connectionState: HAConnectionState { get }
    func connect(baseURL: URL, token: String)
    func disconnect()
    func callService(domain: String, service: String, entityId: String, data: [String: ServiceValue])
    func artworkRequest(for entityPicture: String) -> URLRequest?
}

/// Manages the WebSocket connection to Home Assistant: authenticates, seeds state via `get_states`,
/// then streams `subscribe_entities` diffs and merges them into `entities`.
@Observable
@MainActor
final class HomeAssistantClient: HAClient {
    private let logger = Logger(subsystem: "com.matthewdias.ha-now-playing", category: "HA")

    private(set) var connectionState: HAConnectionState = .disconnected
    private(set) var entities: [String: MediaPlayerState] = [:]

    private var urlSession: URLSession!
    private var webSocketTask: URLSessionWebSocketTask?
    private var messageId = 1
    private var subscriptionId: Int?
    private var reconnectTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var baseURL: URL?
    private var token: String?
    private var reconnectAttempt = 0
    private var pathMonitor: NWPathMonitor?
    private var isNetworkAvailable = true

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func connect(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
        reconnectTask?.cancel()
        startPathMonitor()
        startConnection()
    }

    func disconnect() {
        pathMonitor?.cancel()
        pathMonitor = nil
        pingTask?.cancel()
        pingTask = nil
        reconnectTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionState = .disconnected
        entities = [:]
    }

    func callService(domain: String, service: String, entityId: String, data: [String: ServiceValue] = [:]) {
        let id = nextId()
        let msg = HACallServiceMessage(
            id: id, domain: domain, service: service,
            target: HATarget(entityId: entityId),
            serviceData: data.isEmpty ? nil : data
        )
        send(msg)
    }

    func artworkURL(for entityPicture: String) -> URL? {
        guard let base = baseURL else { return nil }
        if entityPicture.hasPrefix("http") { return URL(string: entityPicture) }
        return URL(string: base.absoluteString + entityPicture)
    }

    func artworkRequest(for entityPicture: String) -> URLRequest? {
        guard let url = artworkURL(for: entityPicture) else { return nil }
        var request = URLRequest(url: url)
        // HA proxy paths need the Bearer token; external URLs (http) are public
        if !entityPicture.hasPrefix("http"), let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - Private

    private func startConnection() {
        guard let base = baseURL, let token = token else { return }
        connectionState = .connecting

        var wsURLString = base.absoluteString
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        if !wsURLString.hasSuffix("/") { wsURLString += "/" }
        wsURLString += "api/websocket"

        guard let wsURL = URL(string: wsURLString) else { return }

        urlSession?.invalidateAndCancel()
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config)
        webSocketTask = urlSession.webSocketTask(with: wsURL)
        webSocketTask?.resume()
        connectionState = .authenticating

        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            await self?.receiveLoop(token: token)
        }
    }

    private func receiveLoop(token: String) async {
        while !Task.isCancelled {
            guard let task = webSocketTask else { break }
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    await handleText(text, token: token)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleText(text, token: token)
                    }
                @unknown default:
                    break
                }
            } catch {
                if !Task.isCancelled {
                    await scheduleReconnect()
                }
                break
            }
        }
    }

    func handleText(_ text: String, token: String) async {
        guard let data = text.data(using: .utf8) else { return }
        do {
            let msg = try JSONDecoder().decode(HAInboundMessage.self, from: data)
            switch msg.type {
            case "auth_required":
                send(HAAuthMessage(accessToken: token))
            case "auth_ok":
                reconnectAttempt = 0
                connectionState = .connected
                seedStates()
                startPingLoop()
            case "auth_invalid":
                connectionState = .failed(HAError.authInvalid)
                webSocketTask?.cancel(with: .normalClosure, reason: nil)
            case "event":
                handleEvent(msg.event)
            case "result":
                if msg.id == subscriptionId { /* subscribe ack */ }
                if let id = msg.id, id == (subscriptionId.map { $0 - 1 }) {
                    // get_states result: handled separately below
                }
                handleResult(msg, raw: data)
            default:
                break
            }
        } catch {
            logger.error("Failed to decode HA message: \(error)")
        }
    }

    private func seedStates() {
        let id = nextId()
        let msg = HAGetStatesMessage(id: id)
        send(msg)
        // subscribe_entities for ongoing diffs
        let subId = nextId()
        subscriptionId = subId
        send(HASubscribeEntitiesMessage(id: subId))
    }

    private func handleResult(_ msg: HAInboundMessage, raw: Data) {
        // get_states returns result as array of entity state objects
        guard msg.success == true else { return }
        if let id = msg.id, id != subscriptionId {
            struct FullState: Decodable {
                let entity_id: String
                let state: String
                let attributes: HAAttributes?
                let last_updated: String?
            }
            struct ResultWrapper: Decodable {
                let result: [FullState]?
            }
            do {
                let wrapper = try JSONDecoder().decode(ResultWrapper.self, from: raw)
                for s in (wrapper.result ?? []) where s.entity_id.hasPrefix("media_player.") {
                    entities[s.entity_id] = buildEntityState(
                        entityId: s.entity_id,
                        stateStr: s.state,
                        attrs: s.attributes,
                        lastUpdated: s.last_updated,
                        using: isoFormatter
                    )
                }
            } catch {
                logger.error("Failed to decode get_states result: \(error)")
            }
        }
    }

    private func handleEvent(_ event: HAEvent?) {
        guard let event = event else { return }

        // Additions
        if let adds = event.add {
            for (entityId, state) in adds where entityId.hasPrefix("media_player.") {
                let luDate = state.lu.map { Date(timeIntervalSince1970: $0) }
                let parsed = buildEntityState(
                    entityId: entityId,
                    stateStr: state.s,
                    attrs: state.a,
                    lastUpdatedDate: luDate,
                    using: isoFormatter
                )
                entities[entityId] = parsed
            }
        }

        // Changes (diffs — merge onto existing)
        if let changes = event.change {
            for (entityId, change) in changes where entityId.hasPrefix("media_player.") {
                guard var existing = entities[entityId] else { continue }
                let luDate = change.added?.lu.map { Date(timeIntervalSince1970: $0) }
                existing = applyEntityChange(change, to: existing, luDate: luDate, using: isoFormatter)
                entities[entityId] = existing
            }
        }

        // Removals
        if let removes = event.remove {
            for entityId in removes { entities.removeValue(forKey: entityId) }
        }
    }

    private func startPathMonitor() {
        pathMonitor?.cancel()
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let available = path.status == .satisfied
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = available
                guard available, !wasAvailable else { return }
                self.logger.info("Network restored — reconnecting immediately")
                self.reconnectAttempt = 0
                self.receiveTask?.cancel()
                switch self.connectionState {
                case .disconnected, .failed:
                    self.startConnection()
                default:
                    break
                }
            }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(HAClientConstants.pingInterval))
                guard !Task.isCancelled else { return }
                await self?.checkPing()
            }
        }
    }

    private func checkPing() async {
        guard let task = webSocketTask else { return }

        let alive = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    task.sendPing { error in continuation.resume(returning: error == nil) }
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(HAClientConstants.pingTimeout))
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        guard !alive, webSocketTask != nil, !Task.isCancelled else { return }
        logger.warning("Ping timed out — connection is dead, reconnecting")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        await scheduleReconnect()
    }

    private func scheduleReconnect() async {
        pingTask?.cancel()
        pingTask = nil
        connectionState = .disconnected
        webSocketTask = nil
        guard isNetworkAvailable else {
            logger.info("Network unavailable — waiting for connectivity to restore")
            return
        }
        let base = min(pow(2.0, Double(reconnectAttempt)), HAClientConstants.maxReconnectDelay)
        let jitter = Double.random(in: 0..<base * 0.5)
        reconnectAttempt += 1
        logger.info("Reconnecting in \(String(format: "%.1f", base + jitter))s (attempt \(self.reconnectAttempt))")
        try? await Task.sleep(nanoseconds: UInt64((base + jitter) * 1_000_000_000))
        if !Task.isCancelled { startConnection() }
    }

    private func send<T: Encodable>(_ message: T) {
        guard let task = webSocketTask else { return }
        do {
            let data = try JSONEncoder().encode(message)
            guard let text = String(data: data, encoding: .utf8) else { return }
            task.send(.string(text)) { _ in }
        } catch {
            logger.error("Failed to encode outgoing message: \(error)")
        }
    }

    private func nextId() -> Int {
        let id = messageId
        messageId += 1
        return id
    }
}

enum HAError: LocalizedError {
    case authInvalid
    var errorDescription: String? {
        switch self {
        case .authInvalid: return "Invalid Home Assistant access token."
        }
    }
}
