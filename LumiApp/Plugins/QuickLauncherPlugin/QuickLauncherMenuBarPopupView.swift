import LumiUI
import SwiftUI

/// 快速启动器插件的菜单栏弹窗视图
struct QuickLauncherMenuBarPopupView: View {
    @State private var manager = QuickLauncherManager.shared

    // 当前选中的分类
    @State private var selectedCategory: AppCategory = .systemTools

    // 搜索文本
    @State private var searchText = ""

    // 应用分类
    enum AppCategory: String, CaseIterable {
        case systemTools = "System"
        case developerTools = "Dev"
        case commonApps = "Apps"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .systemTools: return "gear"
            case .developerTools: return "hammer"
            case .commonApps: return "app.grid"
            case .settings: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            searchBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            GlassDivider()
                .padding(.horizontal, 12)

            // 分类选择器
            categorySelector
                .padding(.vertical, 6)

            GlassDivider()
                .padding(.horizontal, 12)

            // 应用列表
            appList
                .frame(maxHeight: 280)

            GlassDivider()
                .padding(.horizontal, 12)

            // 快捷操作
            quickActionsSection
        }
        .padding(.vertical, 8)
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.adaptive(light: "F2F2F7", dark: "1C1C1E"))
        .cornerRadius(6)
    }

    // MARK: - 分类选择器

    private var categorySelector: some View {
        HStack(spacing: 0) {
            ForEach(AppCategory.allCases, id: \.self) { category in
                QuickLauncherCategoryButton(
                    title: category.rawValue,
                    icon: category.icon,
                    isSelected: selectedCategory == category,
                    action: { selectedCategory = category }
                )
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - 应用列表

    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredApps) { app in
                    AppMenuItem(
                        name: app.name,
                        icon: app.icon,
                        action: { manager.launchApp(app) }
                    )
                }
            }
        }
    }

    // MARK: - 快捷操作

    private var quickActionsSection: some View {
        VStack(spacing: 0) {
            ForEach(manager.quickActions) { action in
                QuickActionMenuItem(
                    name: action.name,
                    icon: action.icon,
                    color: Color(hex: action.color),
                    action: action.action
                )
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 辅助方法

    /// 获取当前分类的应用列表
    private var currentApps: [QuickLauncherManager.AppItem] {
        switch selectedCategory {
        case .systemTools:
            return manager.systemTools
        case .developerTools:
            return manager.developerTools
        case .commonApps:
            return manager.commonApps
        case .settings:
            return manager.settingsItems
        }
    }

    /// 过滤后的应用列表
    private var filteredApps: [QuickLauncherManager.AppItem] {
        if searchText.isEmpty {
            return currentApps
        }
        return currentApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - 分类按钮

private struct QuickLauncherCategoryButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 9))
            }
            .foregroundColor(isSelected ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(isSelected ? Color(hex: "0A84FF").opacity(0.2) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 应用菜单项

private struct AppMenuItem: View {
    let name: String
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isHovering ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : Color(hex: "0A84FF"))
                    .frame(width: 20)

                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(isHovering ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : Color.adaptive(light: "1C1C1E", dark: "EBEBF5"))

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(isHovering ? Color(hex: "0A84FF").opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - 快捷操作菜单项

private struct QuickActionMenuItem: View {
    let name: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isHovering ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : color)
                    .frame(width: 18)

                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(isHovering ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(isHovering ? color.opacity(0.15) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview("Quick Launcher Menu Bar Popup") {
    QuickLauncherMenuBarPopupView()
        .frame(width: 280)
        .padding()
}
