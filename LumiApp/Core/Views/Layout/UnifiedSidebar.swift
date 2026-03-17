import SwiftUI

/// 统一侧边栏视图 - App 模式和 Agent 模式共用
/// 顶部显示模式切换，下方根据不同模式显示不同内容
struct UnifiedSidebar: View {
    @Binding var sidebarVisibility: Bool

    @EnvironmentObject var app: GlobalVM
    @EnvironmentObject var pluginProvider: PluginVM
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 模式切换器（顶部）

            HStack {
                Spacer()
                AppModeSwitcherView()
                    .fixedSize()
                    .padding(.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: AppConfig.headerHeight)

            Divider()
                .background(Color.white.opacity(0.1))

            // MARK: - 模式内容（根据模式显示不同视图）

            modeContent.frame(maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.async {
                initializeDefaultSelection()
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
                    LazyVStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(entries) { entry in
                            Button {
                                app.selectedNavigationId = entry.id
                                // 持久化用户在 App 模式下选择的导航
                                AppSettingsStore.shared.set(entry.id, forKey: "App_SelectedNavigationId")
                            } label: {
                                SidebarRow(title: entry.title, icon: entry.icon, isSelected: app.selectedNavigationId == entry.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.lg)
                }
                .scrollIndicators(.hidden)
            } else {
                emptyState(message: "暂无导航", subtitle: "插件未提供导航入口")
            }

            Spacer(minLength: 0)

            settingsButton
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.md)
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

    // MARK: - 辅助视图

    /// 底部设置按钮
    private var settingsButton: some View {
        Button {
            NotificationCenter.postOpenSettings()
        } label: {
            SidebarRow(title: "设置", icon: "gearshape", isSelected: false)
        }
        .buttonStyle(.plain)
    }

    /// 空状态视图
    private func emptyState(message: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Color.adaptive.textSecondary(for: colorScheme))

            Text(message)
                .font(.headline)
                .foregroundColor(DesignTokens.Color.adaptive.textSecondary(for: colorScheme))

            Text(subtitle)
                .font(.caption)
                .foregroundColor(DesignTokens.Color.adaptive.textTertiary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 私有方法

    /// 初始化默认选中的导航项
    private func initializeDefaultSelection() {
        guard app.selectedMode == .app else { return }

        let entries = pluginProvider.getNavigationEntries(for: .app)

        // 优先从持久化存储中恢复上次选择的导航
        if let savedId = AppSettingsStore.shared.string(forKey: "App_SelectedNavigationId"),
           entries.contains(where: { $0.id == savedId }) {
            app.selectedNavigationId = savedId
            return
        }

        if app.selectedNavigationId == nil {
            if let defaultEntry = entries.first(where: { $0.isDefault }) {
                app.selectedNavigationId = defaultEntry.id
            } else if let firstEntry = entries.first {
                app.selectedNavigationId = firstEntry.id
            }
        }
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let title: String
    let icon: String
    let isSelected: Bool

    /// 当前配色方案
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)
                .frame(width: 20)

            Text(title)
                .font(isSelected ? .system(size: 13, weight: .medium) : .system(size: 13, weight: .regular))
                .foregroundColor(isSelected ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)

            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .background(selectionBackground)
        .overlay(selectionBorder)
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    @ViewBuilder private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(DesignTokens.Color.semantic.primary.opacity(0.15))
                .shadow(color: SwiftUI.Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(SwiftUI.Color.clear)
        }
    }

    @ViewBuilder private var selectionBorder: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(DesignTokens.Color.semantic.primary.opacity(0.3), lineWidth: 1)
        }
    }
}

// MARK: - Preview

#if os(macOS)
    #Preview("Unified Sidebar - App Mode") {
        UnifiedSidebar(sidebarVisibility: .constant(true))
            .frame(width: 220, height: 600)
            .inRootView()
    }
#endif
