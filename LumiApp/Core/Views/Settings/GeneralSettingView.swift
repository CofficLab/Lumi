import ServiceManagement
import SwiftUI

/// General settings view
struct GeneralSettingView: View {
    /// Whether to launch at login
    @State private var launchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 40)

                // Launch at Login
                VStack(alignment: .leading, spacing: 12) {
                    Text("Startup Options")
                        .font(.headline)

                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            updateLaunchAtLogin(newValue)
                        }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .navigationTitle("General")
        .onAppear {
            checkLaunchAtLoginStatus()
        }
    }

    // MARK: - Launch at Login

    /// Check current launch at login status
    private func checkLaunchAtLoginStatus() {
        let job = SMAppService.mainApp.status
        launchAtLogin = (job == .enabled)
    }

    /// Update launch at login status
    /// - Parameter enabled: Whether to enable
    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            // Use new API
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("✅ Launch at login enabled")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("❌ Launch at login disabled")
                }
            } catch {
                print("❌ Failed to update launch at login: \(error.localizedDescription)")
                // Restore toggle state
                launchAtLogin.toggle()
            }
        } else {
            // macOS 12 and earlier
            print("⚠️ Launch at login requires macOS 13.0 or later")
            // Restore toggle state
            launchAtLogin.toggle()
        }
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingView()
}
