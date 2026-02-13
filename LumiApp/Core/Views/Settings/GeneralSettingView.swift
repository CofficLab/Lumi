import ServiceManagement
import SwiftUI

/// General settings view
struct GeneralSettingView: View {
    /// Whether to launch at login
    @State private var launchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                Spacer().frame(height: 40)

                // 启动选项
                startupOptions

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .navigationTitle("通用设置")
        .onAppear {
            checkLaunchAtLoginStatus()
        }
    }

    // MARK: - 启动选项

    private var startupOptions: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "power")
                    .font(.system(size: 20))
                    .foregroundColor(DesignTokens.Color.semantic.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("启动选项")
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Text("管理应用启动行为")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }

                Spacer()
            }
            .padding(.bottom, DesignTokens.Spacing.sm)

            Toggle("登录时启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    updateLaunchAtLogin(newValue)
                }
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

#Preview("通用设置") {
    GeneralSettingView()
        .inRootView()
}

#Preview("通用设置 - 完整应用") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
}
