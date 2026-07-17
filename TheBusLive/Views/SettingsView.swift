import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @AppStorage("com.thebuslive.preferredColorScheme") private var preferredColorSchemeRaw: String = "system"
    @AppStorage(AppPreferenceKeys.accentColor) private var accentColorRaw: String = AppAccentColor.blue.rawValue
    @AppStorage(AppPreferenceKeys.mapStyle) private var mapStyleRaw: String = AppMapStyleOption.standard.rawValue
    @State private var showingClearRecentsConfirmation = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
 // Changes apperance
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $preferredColorSchemeRaw) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accent Color")
                        HStack(spacing: 12) {
                            ForEach(AppAccentColor.allCases) { option in
                                Button {
                                    accentColorRaw = option.rawValue
                                } label: {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(.primary, lineWidth: accentColorRaw == option.rawValue ? 2 : 0)
                                                .padding(-3)
                                        )
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.white)
                                                .opacity(accentColorRaw == option.rawValue ? 1 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.displayName)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Picker("Map Style", selection: $mapStyleRaw) {
                        ForEach(AppMapStyleOption.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                }
                // delte recent stops
                Section("Data") {
                    Button(role: .destructive) {
                        showingClearRecentsConfirmation = true
                    } label: {
                        Label("Clear recent stops", systemImage: "clock.arrow.circlepath")
                    }
                }
                // About section
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: URL(string: "https://hea.thebus.org/api_info.asp")!) {
                        Label("TheBus API registration", systemImage: "link")
                    }
                    Link(destination: URL(string: "https://www.thebus.org")!) {
                        Label("TheBus website", systemImage: "safari")
                    }
                    Link(destination: URL(string: "https://github.com/ashvr0")!) {
                        Label("Made by ashvr0", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!) {
                        Label("Free forever, GPLv3 licensed", systemImage: "checkmark.seal")
                    }
                    Label("No data collected", systemImage: "hand.raised")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text(APIConfig.attributionText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Clear all recently viewed stops?",
                isPresented: $showingClearRecentsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Recents", role: .destructive) {
                    favoritesManager.clearRecents()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(FavoritesManager())
}