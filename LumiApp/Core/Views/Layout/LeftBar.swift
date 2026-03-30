import MagicKit
import SwiftUI

/// 左侧栏视图
/// 顶部显示模式切换，下方根据不同模式显示不同内容
struct LeftSidebar: View {
    @Binding var sidebarVisibility: Bool

    @EnvironmentObject var app: GlobalVM
    @EnvironmentObject var pluginProvider: PluginVM
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 模式切换器（顶部）

            HStack {
                Spacer()
                ModeSwitcherView()
                    .fixedSize()
                    .padding(.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: AppConfig.headerHeight)

            GlassDivider()

            // MARK: - 模式内容（根据模式显示不同视图）

            modeContent
                .frame(maxHeight: .infinity)
        }
        .appSurface(style: .glassUltraThick, cornerRadius: 0)
        .ignoresSafeArea()
        .onAppear {
            // 在 App 模式下，恢复上次选中的导航
            if app.selectedMode == .app {
                restoreAppModeNavigation()
            }
        }
        .onChange(of: app.selectedMode) { _, newMode in
            // 切换到 App 模式时，恢复上次选中的导航
            if newMode == .app {
                restoreAppModeNavigation()
            }
        }
    }

    // MARK: - 模式内容

    @ViewBuilder
    private var modeContent: some View {
        switch app.selectedMode {
        case .app:
            // App 模式：显示导航入口列表
            appModeContent
        case .agent:
            // Agent 模式：显示插件提供的侧边栏视图
            agentModeContent
        }
    }

    // MARK: - App 模式内容

    private var appModeContent: some View {
        VStack(spacing: 0) {
            let entries = pluginProvider.getNavigationEntries(for: app.selectedMode)

            if entries.isNotEmpty {
                ScrollView {
                    LazyVStack(spacing: AppUI.Spacing.sm) {
                        ForEach(entries) { entry in
                            SidebarItemView(title: entry.title, icon: entry.icon, isSelected: app.selectedNavigationId == entry.id) {
                                app.selectedNavigationId = entry.id
                                AppSettingStore.saveSelectedNavigationId(entry.id)
                            }
                        }
                    }
                    .padding(.horizontal, AppUI.Spacing.sm)
                    .padding(.top, AppUI.Spacing.lg)
                    .padding(.bottom, AppUI.Spacing.lg)
                }
                .scrollIndicators(.hidden)
            } else {
                emptyState(message: "暂无导航", subtitle: "插件未提供导航入口")
            }

            Spacer(minLength: 0)

            settingsButton
                .padding(.horizontal, AppUI.Spacing.sm)
                .padding(.bottom, AppUI.Spacing.md)
        }
    }

    // MARK: - Agent 模式内容

    private var agentModeContent: some View {
        let sidebarViews = pluginProvider.getSidebarViews()

        return Group {
            if sidebarViews.isEmpty {
                // 默认内容
                emptyState(message: "Agent 模式侧边栏", subtitle: "暂无插件提供侧边栏视图")
            } else {
                // 显示插件提供的侧边栏视图
                VStack(spacing: 0) {
                    ForEach(Array(sidebarViews.enumerated()), id: \.offset) { _, view in
                        view
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - 辅助方法

    /// 恢复 App 模式下上次选中的导航
    private func restoreAppModeNavigation() {
        let entries = pluginProvider.getNavigationEntries(for: .app)

        guard let savedNavId = AppSettingStore.loadSelectedNavigationId() else {
            // 没有保存的导航，使用默认或第一个可用的导航
            let defaultEntry = entries.first { $0.isDefault } ?? entries.first
            app.selectedNavigationId = defaultEntry?.id
            return
        }

        // 验证保存的导航 ID 是否仍然有效
        if entries.contains(where: { $0.id == savedNavId }) {
            app.selectedNavigationId = savedNavId
        } else {
            // 保存的导航 ID 无效，使用默认或第一个可用的导航
            let defaultEntry = entries.first { $0.isDefault } ?? entries.first
            app.selectedNavigationId = defaultEntry?.id
        }
    }

    // MARK: - 辅助视图

    /// 底部设置按钮
    private var settingsButton: some View {
        SidebarItemView(title: "设置", icon: "gearshape", isSelected: false) {
            NotificationCenter.postOpenSettings()
        }
    }

    /// 空状态视图
    private func emptyState(message: String, subtitle: String) -> some View {
        SidebarEmptyStateView(message: message, subtitle: subtitle)
    }
}

// MARK: - Preview

#if os(macOS)
    #Preview("Left Sidebar - App Mode") {
        LeftSidebar(sidebarVisibility: .constant(true))
            .frame(width: 220, height: 600)
            .inRootView()
    }
#endif

// MARK: - Mode Switcher

/// 应用模式切换器，在 App 模式和 Agent 模式之间切换
private struct ModeSwitcherView: View, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = true

    @EnvironmentObject var app: GlobalVM
    @Environment(\.windowState) var windowState

    @State private var mode: AppMode = .agent
    @State private var isRestoring = false

    var body: some View {
        Picker("模式", selection: $mode) {
            ForEach(AppMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .onAppear(perform: handleOnAppear)
        .onChange(of: self.mode) { _, _ in
            handleModeChanged()
        }
    }
}

private extension ModeSwitcherView {
    func handleOnAppear() {
        isRestoring = true

        // 使用 AppSettingStore 作为单一来源：负责恢复上次的 mode。
        let savedMode = AppSettingStore.loadMode() ?? .agent
        mode = savedMode
        windowState?.selectedMode = savedMode
        app.selectedMode = savedMode

        isRestoring = false
    }

    func handleModeChanged() {
        guard !isRestoring else { return }
        if Self.verbose {
            AppLogger.core.info("\(t)🤖 模式已切换：\(mode.rawValue)")
        }

        // 同时更新窗口级别和全局级别的模式状态
        windowState?.selectedMode = mode
        app.selectedMode = mode

        // 同步到持久化存储：下次启动自动恢复。
        AppSettingStore.saveMode(mode)
    }
}
