import LumiUI
import SwiftUI

/// 设置界面视图，使用 HStack 实现左右并排布局
struct SettingView: View {
    /// 插件 VM
    @EnvironmentObject var pluginProvider: AppPluginVM
    @EnvironmentObject var themeVM: AppThemeVM

    /// 默认显示的标签
    var defaultTab: SettingTab = .about

    /// 当前选中的项
    @State private var selection: SettingsSelection?

    /// 插件分类是否展开
    @State private var isPluginCategoryExpanded: Bool = true

    /// 从 AppSettingStore 读取上次选中的项
    private func loadSavedSelection() -> SettingsSelection? {
        guard let saved = AppSettingStore.loadSettingsSelection() else {
            return nil
        }

        switch saved.type {
        case "core":
            if let tab = SettingTab(rawValue: saved.value) {
                return .core(tab)
            }
        case "plugin":
            return .plugin(saved.value)
        case "pluginCategory":
            if let category = PluginCategory(rawValue: saved.value) {
                return .pluginCategory(category)
            }
        default:
            break
        }
        return nil
    }

    /// 保存选中的项到 AppSettingStore
    private func saveSelection(_ selection: SettingsSelection?) {
        guard let selection = selection else {
            AppSettingStore.clearSettingsSelection()
            return
        }

        switch selection {
        case let .core(tab):
            AppSettingStore.saveSettingsSelection(type: "core", value: tab.rawValue)
        case let .plugin(id):
            AppSettingStore.saveSettingsSelection(type: "plugin", value: id)
        case let .pluginCategory(category):
            AppSettingStore.saveSettingsSelection(type: "pluginCategory", value: category.rawValue)
        }
    }

    /// 初始化方法
    /// - Parameter defaultTab: 默认选中的标签
    init(defaultTab: SettingTab = .about) {
        self.defaultTab = defaultTab
        self._selection = State(initialValue: nil)
    }

    /// 插件设置视图列表
    private var pluginSettings: [(id: String, name: String, icon: String, view: AnyView)] {
        pluginProvider.getPluginSettingsViews()
    }

    /// 按分类分组的可配置插件
    private var groupedPlugins: [(category: PluginCategory, plugins: [any SuperPlugin])] {
        pluginProvider.getConfigurablePluginsGroupedByCategory()
    }

    /// 侧边栏内容视图
    private var sidebarView: some View {
        AppSettingsSidebarContainer {
            VStack(spacing: 0) {
                SettingsSidebarHeaderView()

                AppSettingsDivider()

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(SettingTab.allCases.filter { $0 != .plugins }, id: \.self) { tab in
                            if tab == SettingTab(rawValue: "键盘快捷键") {
                                AppSettingsSidebarItem(
                                    label: Label(tab.rawValue, systemImage: tab.icon),
                                    isSelected: selection == .core(tab)
                                ) {
                                    selection = .core(tab)
                                }

                                pluginCategorySection
                            } else {
                                AppSettingsSidebarItem(
                                    label: Label(tab.rawValue, systemImage: tab.icon),
                                    isSelected: selection == .core(tab)
                                ) {
                                    selection = .core(tab)
                                }
                            }
                        }

                        if !pluginSettings.isEmpty {
                            Divider()
                                .padding(.vertical, 8)

                            ForEach(pluginSettings, id: \.id) { item in
                                AppSettingsSidebarItem(
                                    label: Label(item.name, systemImage: item.icon),
                                    isSelected: selection == .plugin(item.id)
                                ) {
                                    selection = .plugin(item.id)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    /// 插件管理可展开分组区域
    private var pluginCategorySection: some View {
        AppSettingsExpandableSidebarGroup(
            isExpanded: $isPluginCategoryExpanded,
            title: "插件管理",
            systemImage: "puzzlepiece.extension"
        ) {
            ForEach(groupedPlugins, id: \.category) { group in
                AppSettingsSidebarItem(
                    label: Label {
                        Text(group.category.displayName)
                    } icon: {
                        Image(systemName: group.category.systemImage)
                    },
                    isSelected: selection == .pluginCategory(group.category)
                ) {
                    selection = .pluginCategory(group.category)
                }
                .padding(.leading, 16)
            }
        }
    }

    /// 详情区域视图
    private var detailView: some View {
        AppSettingsDetailPane {
            Group {
                if let sel = selection {
                    switch sel {
                    case let .core(tab):
                        tab.destinationView
                    case let .plugin(id):
                        if let item = pluginSettings.first(where: { $0.id == id }) {
                            item.view
                        } else {
                            Text("插件未找到或已禁用")
                                .foregroundColor(.secondary)
                        }
                    case let .pluginCategory(category):
                        PluginCategorySettingsView(category: category)
                    }
                } else {
                    Text("请选择设置项")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    var body: some View {
        AppSettingsSidebarShell {
            sidebarView
        } detail: {
            detailView
        }
        .onAppear {
            // 加载上次选中的项
            if let savedSelection = loadSavedSelection() {
                selection = savedSelection
            } else {
                selection = .core(defaultTab)
            }
        }
        .onChange(of: selection) { _, newValue in
            // 保存选中的项
            saveSelection(newValue)
        }
        .background {
            GeometryReader { proxy in
                themeVM.activeChromeTheme.makeGlobalBackground(proxy: proxy)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Preview

#Preview {
    SettingView()
        .inRootView()
}

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
