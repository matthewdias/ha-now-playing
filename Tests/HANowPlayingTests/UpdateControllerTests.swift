import Testing
@testable import HANowPlaying

@Suite("UpdateController")
@MainActor
struct UpdateControllerTests {

    let controller = UpdateController()

    @Test func scheduledUpdateSetsAvailable() {
        controller.handleScheduledUpdate(userInitiated: false)
        #expect(controller.updateAvailable == true)
    }

    @Test func userInitiatedUpdateDoesNotSetAvailable() {
        controller.handleScheduledUpdate(userInitiated: true)
        #expect(controller.updateAvailable == false)
    }

    @Test func userAttentionClearsAvailable() {
        controller.handleScheduledUpdate(userInitiated: false)
        controller.handleUserAttention()
        #expect(controller.updateAvailable == false)
    }

    @Test func updateSessionFinishedClearsAvailable() {
        controller.handleScheduledUpdate(userInitiated: false)
        controller.handleUpdateSessionFinished()
        #expect(controller.updateAvailable == false)
    }

    @Test func supportsGentleReminders() {
        #expect(controller.supportsGentleScheduledUpdateReminders == true)
    }
}
