import SwiftUI

extension HAConnectionState {
    var label: String {
        switch self {
        case .connected:      return "Connected"
        case .connecting:     return "Connecting…"
        case .authenticating: return "Authenticating…"
        case .disconnected:   return "Disconnected"
        case .failed(let e):  return e.localizedDescription
        }
    }

    var color: Color {
        switch self {
        case .connected:                   return .green
        case .connecting, .authenticating: return .orange
        case .disconnected, .failed:       return .red
        }
    }
}
