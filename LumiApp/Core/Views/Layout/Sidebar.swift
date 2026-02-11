import SwiftUI

/// 侧边栏视图，显示插件提供的导航入口
struct Sidebar: View {
    /// 应用提供者环境对象
    @EnvironmentObject var appProvider: AppProvider

    /// 插件提供者环境对象
    @EnvironmentObject var pluginProvider: PluginProvider

    private var entries: [NavigationEntry] {
        pluginProvider.getNavigationEntries()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 导航列表区域
            Group {
                if entries.isNotEmpty {
                        List(entries, selection: $appProvider.selectedNavigationId) { entry in
                            SidebarRow(entry: entry, isSelected: appProvider.selectedNavigationId == entry.id)
                        }
                        .listStyle(.sidebar)
                        .scrollContentBackground(.hidden)
                        .background(DesignTokens.Material.glass)
                } else {
                    // 空状态
                    emptyState
                }
            }
            
            Spacer()

            // 底部设置按钮
            settingsButton
        }
        .background(DesignTokens.Material.glass)
        .onAppear {
            // Delay to avoid "Publishing changes during view update" warning
            DispatchQueue.main.async {
                initializeDefaultSelection()
            }
        }
    }
    
    struct SidebarRow: View {
        let entry: NavigationEntry
        let isSelected: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                // 图标背景
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(DesignTokens.Color.gradients.primaryGradient)
                    } else {
                        Circle()
                            .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.15))
                    }
                }
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: entry.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)
                )

                // 标题
                Text(entry.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? DesignTokens.Color.semantic.textPrimary : DesignTokens.Color.semantic.textSecondary)

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
    }

    /// 底部设置按钮
    private var settingsButton: some View {
        Button {
            NotificationCenter.postOpenSettings()
        } label: {
            GlassRow {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        .frame(width: 24)

                    Text("设置")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 空状态视图
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Text("暂无导航")
                .font(.headline)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Text("插件未提供导航入口")
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
