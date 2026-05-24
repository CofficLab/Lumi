import AppKit
import ServiceManagement
import SwiftUI
import LumiUI

/// General settings view
struct GeneralSettingView: View {
    /// Whether to launch at login
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部说明卡片（固定）
            headerCard
                .padding(24)
                .background(Color.clear)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 启动选项
                    startupSection

                    // 新手引导
                    onboardingSection

                    // 反馈与支持
                    supportSection

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            checkLaunchAtLoginStatus()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        AppCard {
            AppSettingsSection(title: "通用设置", subtitle: "管理应用的基本行为和偏好设置") {}
        }
    }

    // MARK: - 启动选项

    private var startupSection: some View {
        AppCard {
            AppSettingsSection(title: "启动选项", subtitle: "管理应用启动行为", spacing: 12) {
                AppSettingsToggleRow("登录时启动", systemImage: "power", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
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
        AppCard {
            AppSettingsSection(title: "新手引导", subtitle: "随时重新查看产品使用指引", spacing: 12) {
                AppButton("重新查看新手引导", style: .secondary, fillsWidth: true, action: {
                    NotificationCenter.default.post(
                        name: Notification.Name("Onboarding.Show"),
                        object: nil,
                        userInfo: ["reset": true]
                    )
                })
            }
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        AppCard {
            AppSettingsSection(title: "反馈与支持", subtitle: "遇到问题时可直接提交 Issue，帮助我们快速定位", spacing: 12) {
                HStack(spacing: 8) {
                    AppButton("报告问题", style: .primary, fillsWidth: true, action: { openURL("https://github.com/CofficLab/Lumi/issues/new/choose") })
                    .accessibilityLabel("报告问题")
                    .accessibilityHint("在 GitHub 打开问题反馈页面")

                    AppButton("查看 Issue 列表", style: .secondary, fillsWidth: true, action: { openURL("https://github.com/CofficLab/Lumi/issues") })
                    .accessibilityLabel("查看 Issue 列表")
                    .accessibilityHint("在浏览器打开公开问题列表")
                }
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
        .inRootView()
}
