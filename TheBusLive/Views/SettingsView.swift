import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @AppStorage("com.thebuslive.preferredColorScheme") private var preferredColorSchemeRaw: String = "system"
    @State private var showingClearRecentsConfirmation = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $preferredColorSchemeRaw) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }

                Section("Data") {
                    Button(role: .destructive) {
                        showingClearRecentsConfirmation = true
                    } label: {
                        Label("Clear recent stops", systemImage: "clock.arrow.circlepath")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: URL(string: "https://hea.thebus.org/api_info.asp")!) {
                        Label("TheBus API registration", systemImage: "link")
                    }
                    Link(destination: URL(string: "https://www.thebus.org")!) {
                        Label("TheBus website", systemImage: "safari")
                    }
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
