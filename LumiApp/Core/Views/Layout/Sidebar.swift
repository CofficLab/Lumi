import SwiftUI

/// 侧边栏视图，显示插件提供的导航入口
struct Sidebar: View {
    /// 应用提供者环境对象
    @EnvironmentObject var appProvider: AppProvider

    /// 插件提供者环境对象
    @EnvironmentObject var pluginProvider: PluginProvider

    /// 当前配色方案（浅色/深色模式）
    @Environment(\.colorScheme) private var colorScheme

    private var entries: [NavigationEntry] {
        pluginProvider.getNavigationEntries()
    }

    var body: some View {
        VStack(spacing: 0) {
            if entries.isNotEmpty {
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(entries) { entry in
                            Button {
                                appProvider.selectedNavigationId = entry.id
                            } label: {
                                SidebarRow(title: entry.title, icon: entry.icon, isSelected: appProvider.selectedNavigationId == entry.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.top, 40) // 为流量灯留出空间
                    .padding(.bottom, DesignTokens.Spacing.lg)
                }
                .scrollIndicators(.hidden)
            } else {
                emptyState
            }

            Spacer(minLength: 0)

            settingsButton
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.md)
        }
        .background(SwiftUI.Color.clear)
        .onAppear {
            // Delay to avoid "Publishing changes during view update" warning
            DispatchQueue.main.async {
                initializeDefaultSelection()
            }
        }
    }
    
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
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .frame(width: 20)

                Text(title)
                    .font(isSelected ? .system(size: 13, weight: .medium) : .system(size: 13, weight: .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))

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
                    .fill(SwiftUI.Color.white.opacity(0.15))
                    .shadow(color: SwiftUI.Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(SwiftUI.Color.clear)
            }
        }

        @ViewBuilder private var selectionBorder: some View {
            if isSelected {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(SwiftUI.Color.white.opacity(0.2), lineWidth: 1)
            }
        }
    }

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
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Color.adaptive.textSecondary(for: colorScheme))

            Text("暂无导航")
                .font(.headline)
                .foregroundColor(DesignTokens.Color.adaptive.textSecondary(for: colorScheme))

            Text("插件未提供导航入口")
                .font(.caption)
                .foregroundColor(DesignTokens.Color.adaptive.textTertiary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebarBackground: some View {
        ZStack {
            Rectangle()
                .fill(DesignTokens.Material.mysticGlass(for: colorScheme))
            LinearGradient(
                colors: [
                    DesignTokens.Color.basePalette.mysticIndigo.opacity(0.6),
                    DesignTokens.Color.basePalette.mysticViolet.opacity(0.45),
                    DesignTokens.Color.basePalette.mysticAzure.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? 0.45 : 0.2)
        }
        .ignoresSafeArea()
    }

    /// 初始化默认选中的导航项
    private func initializeDefaultSelection() {
        // 如果还没有选中项，选择默认的或第一个
        if appProvider.selectedNavigationId == nil {
            let entries = pluginProvider.getNavigationEntries()
            if let defaultEntry = entries.first(where: { $0.isDefault }) {
                appProvider.selectedNavigationId = defaultEntry.id
            } else if let firstEntry = entries.first {
                appProvider.selectedNavigationId = firstEntry.id
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Sidebar()
        .inRootView()
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
