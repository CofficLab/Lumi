import AppKit
import ServiceManagement
import SwiftUI

/// General settings view
struct GeneralSettingView: View {
    /// Whether to launch at login
    @State private var launchAtLogin = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                // 顶部说明卡片（固定）
                Section {
                    Spacer().frame(height: DesignTokens.Spacing.lg)

                    // 启动选项
                    startupSection

                    // 新手引导
                    onboardingSection

                    // 反馈与支持
                    supportSection

                    Spacer()
                } header: {
                    headerCard
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .background(Color.clear)
                }
            }
        }
        .navigationTitle("通用设置")
        .onAppear {
            checkLaunchAtLoginStatus()
        }
    }

    // MARK: - Header Card (Sticky)

    private var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GlassSectionHeader(
                    icon: "gearshape.2",
                    title: "通用设置",
                    subtitle: "管理应用的基本行为和偏好设置"
                )

                GlassDivider()

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(DesignTokens.Color.semantic.primary)
                        .font(.system(size: 14))

                    Text("配置应用的启动行为、查看新手引导或提交问题反馈")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }
        }
    }

    // MARK: - 启动选项

    private var startupSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GlassSectionHeader(
                    icon: "power",
                    title: "启动选项",
                    subtitle: "管理应用启动行为"
                )

                GlassDivider()

                GlassRow {
                    HStack {
                        Text("登录时启动")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                        Spacer()

                        Toggle("", isOn: $launchAtLogin)
                            .labelsHidden()
                            .onChange(of: launchAtLogin) { _, newValue in
                                updateLaunchAtLogin(newValue)
                            }
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
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
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GlassSectionHeader(
                    icon: "graduationcap",
                    title: "新手引导",
                    subtitle: "随时重新查看产品使用指引"
                )

                GlassDivider()

                GlassButton(title: "重新查看新手引导", style: .secondary) {
                    NotificationCenter.default.post(
                        name: Notification.Name("AgentOnboarding.Show"),
                        object: nil,
                        userInfo: ["reset": true]
                    )
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }

    // MARK: - Support

    private var supportSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GlassSectionHeader(
                    icon: "lifepreserver",
                    title: "反馈与支持",
                    subtitle: "遇到问题时可直接提交 Issue，帮助我们快速定位"
                )

                GlassDivider()

                HStack(spacing: DesignTokens.Spacing.sm) {
                    GlassButton(title: "报告问题", style: .primary) {
                        openURL("https://github.com/CofficLab/Lumi/issues/new/choose")
                    }
                    .accessibilityLabel("报告问题")
                    .accessibilityHint("在 GitHub 打开问题反馈页面")

                    GlassButton(title: "查看 Issue 列表", style: .secondary) {
                        openURL("https://github.com/CofficLab/Lumi/issues")
                    }
                    .accessibilityLabel("查看 Issue 列表")
                    .accessibilityHint("在浏览器打开公开问题列表")
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
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
