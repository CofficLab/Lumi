import LumiUI
import SwiftUI

/// 设置界面视图，使用 HStack 实现左右并排布局
struct SettingView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 插件 VM
    @EnvironmentObject var pluginProvider: AppPluginVM
    @EnvironmentObject var themeVM: AppThemeVM

    /// 默认显示的标签
    var defaultTab: SettingTab = .about

    /// 当前选中的项
    @State private var selection: SettingsSelection?

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
            // 分类入口已合并到插件管理视图内部，旧数据自动回退到插件管理页
            return .core(.plugins)
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
        case .pluginCategory:
            // 分类入口已移除，不再保存
            AppSettingStore.clearSettingsSelection()
        case let .plugin(id):
            AppSettingStore.saveSettingsSelection(type: "plugin", value: id)
        }
    }

    private func applyStoredOrDefaultSelection() {
        if let savedSelection = loadSavedSelection() {
            selection = savedSelection
        } else {
            selection = .core(defaultTab)
        }
    }

    /// 初始化方法
    /// - Parameter defaultTab: 默认选中的标签
    init(defaultTab: SettingTab = .about) {
        self.defaultTab = defaultTab
        self._selection = State(initialValue: nil)
    }

    /// 插件设置视图列表（单独提供了 addSettingsView 的插件）
    private var pluginSettings: [(id: String, name: String, icon: String, view: AnyView)] {
        pluginProvider.getPluginSettingsViews()
    }

    /// 侧边栏内容视图
    private var sidebarView: some View {
        AppSettingsSidebarContainer {
            VStack(spacing: 0) {
                SettingsSidebarHeaderView()

                AppSettingsDivider()

                ScrollView {
                    LazyVStack(spacing: 4) {
                        // 核心设置项
                        ForEach(SettingTab.allCases, id: \.self) { tab in
                            AppSettingsSidebarItem(
                                label: Label(tab.rawValue, systemImage: tab.icon),
                                isSelected: selection == .core(tab)
                            ) {
                                selection = .core(tab)
                            }
                        }

                        // 单独提供设置视图的插件
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

    /// 详情区域视图
    private var detailView: some View {
        AppSettingsDetailPane {
            Group {
                if let sel = selection {
                    switch sel {
                    case let .core(tab):
                        tab.destinationView
                    case let .pluginCategory(category):
                        PluginCategorySettingsView(category: category)
                    case let .plugin(id):
                        if let item = pluginSettings.first(where: { $0.id == id }) {
                            item.view
                        } else {
                            Text("插件未找到或已禁用")
                                .foregroundColor(.secondary)
                        }
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
            applyStoredOrDefaultSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            applyStoredOrDefaultSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPluginSettings)) { _ in
            applyStoredOrDefaultSelection()
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
}
