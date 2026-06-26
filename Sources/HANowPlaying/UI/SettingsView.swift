import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) var store
    @State private var haURL   = ""
    @State private var haToken = ""
    @State private var showToken = false
    @State private var saveState: SaveState = .idle

    enum SaveState { case idle, saved }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)

            fieldsCard
                .padding(.horizontal, 20)

            hintText
                .padding(.horizontal, 24)
                .padding(.top, 10)

            actionsRow
                .padding(.horizontal, 24)
                .padding(.top, 16)

            if !store.allEntities.isEmpty {
                playersCard
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                Text(
                    "Enabled players appear in the device picker and can be automatically selected for Now Playing. " +
                    "Disabled players are ignored entirely."
                )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
            }

            Spacer()
                .frame(height: 24)
        }
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            let creds = store.loadCredentials()
            haURL   = creds.url
            haToken = creds.token
            bringToForeground()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.gradient)
                    .frame(width: 44, height: 44)
                Image(systemName: "house.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Home Assistant")
                    .font(.headline)
                Text("Configure server connection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(store.connectionState.color)
                .frame(width: 7, height: 7)
            Text(store.connectionState.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            fieldRow(label: "URL", labelWidth: 56) {
                TextField("http://homeassistant.local:8123", text: $haURL)
                    .textFieldStyle(.plain)
                    .labelsHidden()
            }
            Divider()
                .padding(.leading, 16)
            fieldRow(label: "Token", labelWidth: 56) {
                Group {
                    if showToken {
                        TextField("Long-lived access token", text: $haToken)
                            .textFieldStyle(.plain)
                    } else {
                        SecureField("Long-lived access token", text: $haToken)
                            .textFieldStyle(.plain)
                    }
                }
                Button {
                    showToken.toggle()
                } label: {
                    Image(systemName: showToken ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator, lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private func fieldRow<Content: View>(
        label: String, labelWidth: CGFloat, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var playersCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Media Players")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()
                .padding(.leading, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(store.allEntities.enumerated()), id: \.element.id) { index, entity in
                        let isHidden = store.hiddenEntityIds.contains(entity.entityId)

                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entity.friendlyName)
                                    .font(.subheadline)
                                    .foregroundStyle(isHidden ? .secondary : .primary)
                                Text(entity.entityId)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !isHidden },
                                set: { store.setHidden(entity.entityId, hidden: !$0) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)

                        if index < store.allEntities.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator, lineWidth: 0.5)
        }
    }

    private var hintText: some View {
        Text("Generate a token in your HA profile under **Security → Long-lived access tokens**.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            if store.isConfigured {
                Button("Disconnect", role: .destructive) {
                    store.disconnect()
                    haURL   = ""
                    haToken = ""
                }
                .foregroundStyle(.red)
                .buttonStyle(.plain)
                .font(.subheadline)
            }
            Spacer()
            if case .saved = saveState {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            Button("Save & Connect") {
                guard store.connect(haURL: haURL, token: haToken) else { return }
                withAnimation(.spring(duration: 0.25)) { saveState = .saved }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { saveState = .idle }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(haURL.isEmpty || haToken.isEmpty)
        }
        .animation(.default, value: saveState == .saved)
    }

    // MARK: - Window management

    private func bringToForeground() {
        NSApp.activate(ignoringOtherApps: true)
        // Give the Settings window time to appear, then raise it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.windows
                .filter { $0.canBecomeKey && !$0.title.isEmpty }
                .forEach { $0.makeKeyAndOrderFront(nil) }
        }
    }
}

extension SettingsView.SaveState: Equatable {}
