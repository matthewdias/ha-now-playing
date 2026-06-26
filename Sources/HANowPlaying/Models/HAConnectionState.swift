enum HAConnectionState {
    case disconnected, connecting, authenticating, connected, failed(Error)
}
