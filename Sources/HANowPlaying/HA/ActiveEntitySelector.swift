import Foundation
import Observation

/// Picks which single media_player entity owns the Now Playing slot.
/// Auto mode: the most-recently-active playing entity wins.
/// Manual mode: user explicitly pins an entity.
@Observable
@MainActor
final class ActiveEntitySelector {
    enum Mode { case auto, manual(String) }

    private(set) var activeEntityId: String?
    var mode: Mode = .auto

    private var lastActiveDates: [String: Date] = [:]
    private static let pinnedKey = "pinned_entity_id"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.string(forKey: Self.pinnedKey) {
            mode = .manual(saved)
            activeEntityId = saved
        }
    }

    func update(entities: [String: MediaPlayerState]) {
        switch mode {
        case .manual(let id):
            activeEntityId = entities[id] != nil ? id : nil

        case .auto:
            // Among playing entities, pick the one that became playing most recently.
            // Fall back to most recently paused if nothing is playing.
            let playing = entities.values.filter { $0.playbackState == .playing }
            let paused  = entities.values.filter { $0.playbackState == .paused }
            let candidates = playing.isEmpty ? Array(paused) : playing

            if candidates.isEmpty {
                activeEntityId = nil
                return
            }

            // Track when entities entered a playing/paused state
            for entity in candidates where lastActiveDates[entity.entityId] == nil {
                lastActiveDates[entity.entityId] = Date()
            }
            // Clear stale dates for entities no longer active
            let activeIds = Set(candidates.map(\.entityId))
            lastActiveDates = lastActiveDates.filter { activeIds.contains($0.key) }

            activeEntityId = candidates.max(by: {
                (lastActiveDates[$0.entityId] ?? .distantPast) < (lastActiveDates[$1.entityId] ?? .distantPast)
            })?.entityId
        }
    }

    func pin(entityId: String?) {
        if let id = entityId {
            mode = .manual(id)
            activeEntityId = id
            defaults.set(id, forKey: Self.pinnedKey)
        } else {
            mode = .auto
            defaults.removeObject(forKey: Self.pinnedKey)
        }
    }

    var isPinned: Bool {
        if case .manual = mode { return true }
        return false
    }
}
