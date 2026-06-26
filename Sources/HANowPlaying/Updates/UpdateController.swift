import AppKit
import Combine
import Sparkle

@Observable
@MainActor
final class UpdateController: NSObject, SPUStandardUserDriverDelegate {
    private(set) var updateAvailable = false
    private(set) var canCheckForUpdates = false
    private var updaterController: SPUStandardUpdaterController?
    private var cancellable: AnyCancellable?

    override init() {
        super.init()
    }

    func start() {
        #if !DEBUG
        guard updaterController == nil else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
        updaterController = controller
        cancellable = controller.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.canCheckForUpdates = value }
        #endif
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    // MARK: - SPUStandardUserDriverDelegate

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        Task { @MainActor in
            self.handleScheduledUpdate(userInitiated: state.userInitiated)
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor in
            self.handleUserAttention()
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in
            self.handleUpdateSessionFinished()
        }
    }

    // MARK: - Testable state transitions

    func handleScheduledUpdate(userInitiated: Bool) {
        if !userInitiated { updateAvailable = true }
    }

    func handleUserAttention() {
        updateAvailable = false
    }

    func handleUpdateSessionFinished() {
        updateAvailable = false
    }
}
