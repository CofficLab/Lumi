import AppKit
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
                startupSection

                onboardingSection

                supportSection

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

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(
                icon: "power",
                title: "启动选项",
                subtitle: "管理应用启动行为"
            )

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
                    AppLogger.core.info("✅ Launch at login enabled")
                } else {
                    try SMAppService.mainApp.unregister()
                    AppLogger.core.info("❌ Launch at login disabled")
                }
            } catch {
                AppLogger.core.error("❌ Failed to update launch at login: \(error.localizedDescription)")
                // Restore toggle state
                launchAtLogin.toggle()
            }
        } else {
            // macOS 12 and earlier
            AppLogger.core.info("⚠️ Launch at login requires macOS 13.0 or later")
            // Restore toggle state
            launchAtLogin.toggle()
        }
    }

    // MARK: - Onboarding

    private var onboardingSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(
                icon: "graduationcap",
                title: "新手引导",
                subtitle: "随时重新查看产品使用指引"
            )

            Button("重新查看新手引导") {
                NotificationCenter.default.post(
                    name: Notification.Name("AgentOnboarding.Show"),
                    object: nil,
                    userInfo: ["reset": true]
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GlassSectionHeader(
                icon: "lifepreserver",
                title: "反馈与支持",
                subtitle: "遇到问题时可直接提交 Issue，帮助我们快速定位"
            )

            HStack(spacing: DesignTokens.Spacing.sm) {
                Button("报告问题") {
                    openURL("https://github.com/CofficLab/Lumi/issues/new/choose")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("报告问题")
                .accessibilityHint("在 GitHub 打开问题反馈页面")

                Button("查看 Issue 列表") {
                    openURL("https://github.com/CofficLab/Lumi/issues")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("查看 Issue 列表")
                .accessibilityHint("在浏览器打开公开问题列表")
            }
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
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
