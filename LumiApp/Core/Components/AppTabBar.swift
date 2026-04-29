import SwiftUI

// MARK: - AppTabBar

/// 统一的 Tab 切换条组件
///
/// 用于替代 SeriesTabButton、ProviderButton 以及手写的 Picker(.segmented) 模式。
/// 支持单选和多选项展示。
///
/// ## 使用示例
/// ```swift
/// // 简单 Tab 条
/// AppTabBar(
///     tabs: ["已下载", "模型列表"],
///     selectedTab: $selectedTab
/// )
///
/// // 带图标的 Tab 条
/// AppTabBar(
///     tabs: [
///         AppTabBar.Tab(title: "已安装", icon: "checkmark.circle"),
///         AppTabBar.Tab(title: "可更新", icon: "arrow.clockwise")
///     ],
///     selectedTab: $selectedTab
/// )
/// ```
struct AppTabBar: View {
    /// Tab 项定义
    struct Tab: Identifiable, Equatable {
        let id: String
        let title: String
        let icon: String?

        init(title: String, icon: String? = nil, id: String? = nil) {
            self.id = id ?? title
            self.title = title
            self.icon = icon
        }

        static func == (lhs: Tab, rhs: Tab) -> Bool {
            lhs.id == rhs.id
        }
    }

    let tabs: [Tab]
    @Binding var selectedTab: String
    var showText: Bool = true

    /// 简单初始化：仅标题
    init(tabs: [String], selectedTab: Binding<String>) {
        self.tabs = tabs.map { Tab(title: $0) }
        self._selectedTab = selectedTab
    }

    /// 完整初始化：带图标
    init(tabs: [Tab], selectedTab: Binding<String>, showText: Bool = true) {
        self.tabs = tabs
        self._selectedTab = selectedTab
        self.showText = showText
    }

    var body: some View {
        HStack(spacing: AppUI.Spacing.sm) {
            ForEach(tabs) { tab in
                AppTabButton(
                    title: tab.title,
                    icon: tab.icon,
                    isSelected: selectedTab == tab.id,
                    showText: showText
                ) {
                    selectedTab = tab.id
                }
            }
        }
    }
}

// MARK: - Tab Button

private struct AppTabButton: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let showText: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                if showText {
                    Text(title)
                        .font(AppUI.Typography.caption1)
                }
            }
            .foregroundColor(isSelected ? .white : AppUI.Color.semantic.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: DesignTokens.Duration.micro)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            AppUI.Color.semantic.primary
        } else if isHovered {
            Color.white.opacity(0.12)
        } else {
            Color.white.opacity(0.05)
        }
    }
}

// MARK: - Preview

#Preview("AppTabBar - 简单") {
    struct PreviewWrapper: View {
        @State private var selected = "已下载"
        var body: some View {
            AppTabBar(tabs: ["已下载", "模型列表"], selectedTab: $selected)
                .padding()
                .frame(width: 300)
                .background(AppUI.Color.basePalette.deepBackground)
        }
    }
    return PreviewWrapper()
}

#Preview("AppTabBar - 带图标") {
    struct PreviewWrapper: View {
        @State private var selected = "installed"
        var body: some View {
            AppTabBar(
                tabs: [
                    AppTabBar.Tab(title: "已安装", icon: "checkmark.circle", id: "installed"),
                    AppTabBar.Tab(title: "可更新", icon: "arrow.clockwise", id: "updates"),
                    AppTabBar.Tab(title: "搜索", icon: "magnifyingglass", id: "search")
                ],
                selectedTab: $selected
            )
            .padding()
            .frame(width: 400)
            .background(AppUI.Color.basePalette.deepBackground)
        }
    }
    return PreviewWrapper()
}