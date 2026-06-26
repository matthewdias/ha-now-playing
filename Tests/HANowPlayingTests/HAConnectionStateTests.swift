import Testing
@testable import HANowPlaying
import SwiftUI

@Suite("HAConnectionState+UI")
struct HAConnectionStateTests {

    // MARK: - label

    @Test func connectedLabel() {
        #expect(HAConnectionState.connected.label == "Connected")
    }

    @Test func connectingLabel() {
        #expect(HAConnectionState.connecting.label == "Connecting…")
    }

    @Test func authenticatingLabel() {
        #expect(HAConnectionState.authenticating.label == "Authenticating…")
    }

    @Test func disconnectedLabel() {
        #expect(HAConnectionState.disconnected.label == "Disconnected")
    }

    @Test func failedLabelUsesErrorDescription() {
        let error = HAError.authInvalid
        #expect(HAConnectionState.failed(error).label == error.localizedDescription)
    }

    // MARK: - color

    @Test func connectedColor() {
        #expect(HAConnectionState.connected.color == .green)
    }

    @Test func connectingColor() {
        #expect(HAConnectionState.connecting.color == .orange)
    }

    @Test func authenticatingColor() {
        #expect(HAConnectionState.authenticating.color == .orange)
    }

    @Test func disconnectedColor() {
        #expect(HAConnectionState.disconnected.color == .red)
    }

    @Test func failedColor() {
        #expect(HAConnectionState.failed(HAError.authInvalid).color == .red)
    }
}
