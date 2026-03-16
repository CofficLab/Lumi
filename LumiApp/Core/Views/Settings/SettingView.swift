import SwiftUI

/// 设置界面视图，包含侧边栏导航和详情区域
/// 在独立窗口中显示
struct SettingView: View {
    /// 插件 VM
    @EnvironmentObject private var pluginProvider: PluginVM
    @EnvironmentObject var themeManager: MystiqueThemeManager

    /// 导航分栏视图的列可见性状态
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// 默认显示的标签
    var defaultTab: SettingTab = .about

    /// 设置选择枚举
    enum SettingsSelection: Hashable {
        case core(SettingTab)
        case plugin(String)
    }

    /// 设置标签枚举
    enum SettingTab: String, CaseIterable, Hashable {
        case general = "通用"
        case theme = "主题"
        case localProvider = "本地供应商"
        case remoteProvider = "云端供应商"
        case plugins = "插件管理"
        case about = "关于"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .theme: return "paintbrush.fill"
            case .localProvider: return "cpu"
            case .remoteProvider: return "network"
            case .plugins: return "puzzlepiece.extension"
            case .about: return "info.circle"
            }
        }
    }

    /// 当前选中的项
    @State private var selection: SettingsSelection?

    /// AppSettingsStore key
    private static let selectedTabKey = "SettingView.selectedTab"
    private static let selectedPluginKey = "SettingView.selectedPlugin"

    /// 从 AppSettingsStore 读取上次选中的项
    private func loadSavedSelection() -> SettingsSelection? {
        // 先尝试读取插件
        if let pluginId = AppSettingsStore.shared.string(forKey: Self.selectedPluginKey) {
            return .plugin(pluginId)
        }

        // 再尝试读取核心设置项
        if let tabRawValue = AppSettingsStore.shared.string(forKey: Self.selectedTabKey),
           let tab = SettingTab(rawValue: tabRawValue) {
            return .core(tab)
        }

        return nil
    }

    /// 保存选中的项到 AppSettingsStore
    private func saveSelection(_ selection: SettingsSelection?) {
        guard let sel = selection else { return }

        switch sel {
        case let .core(tab):
            AppSettingsStore.shared.set(tab.rawValue, forKey: Self.selectedTabKey)
            AppSettingsStore.shared.removeObject(forKey: Self.selectedPluginKey)
        case let .plugin(pluginId):
            AppSettingsStore.shared.set(pluginId, forKey: Self.selectedPluginKey)
            AppSettingsStore.shared.removeObject(forKey: Self.selectedTabKey)
        }
    }

    /// 初始化方法
    /// - Parameter defaultTab: 默认选中的标签
    init(defaultTab: SettingTab = .about) {
        self.defaultTab = defaultTab
        self._selection = State(initialValue: nil)
    }

    /// 应用信息
    private var appInfo: AppInfo {
        AppInfo()
    }

    /// 插件设置视图列表
    private var pluginSettings: [(id: String, name: String, icon: String, view: AnyView)] {
        pluginProvider.getPluginSettingsViews()
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 侧边栏
            VStack(spacing: 0) {
                // 应用信息头部
                sidebarHeader

                GlassDivider()

                // 设置列表
                List(selection: $selection) {
                    Section {
                        ForEach(SettingTab.allCases, id: \.self) { tab in
                            NavigationLink(value: SettingsSelection.core(tab)) {
                                Label(tab.rawValue, systemImage: tab.icon)
                            }
                        }
                    }

                    if !pluginSettings.isEmpty {
                        Section("插件设置") {
                            ForEach(pluginSettings, id: \.id) { item in
                                NavigationLink(value: SettingsSelection.plugin(item.id)) {
                                    Label(item.name, systemImage: item.icon)
                                }
                            }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 300)
            .ignoresSafeArea()
        } detail: {
            // 详情区域
            Group {
                if let sel = selection {
                    switch sel {
                    case let .core(tab):
                        switch tab {
                        case .general:
                            GeneralSettingView()
                        case .theme:
                            ThemeSettingView()
                        case .localProvider:
                            LocalProviderSettingsView()
                        case .remoteProvider:
                            RemoteProviderSettingsView()
                        case .plugins:
                            PluginSettingsView()
                        case .about:
                            AboutView()
                        }
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
            // 当左侧侧边栏未被隐藏时，详情区域忽略顶部安全区域
            .ignoresSafeArea(edges: columnVisibility == .detailOnly ? [] : .top)
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
                themeManager.currentVariant.theme.makeGlobalBackground(proxy: proxy)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - View

    /// 侧边栏头部 - 应用信息
    private var sidebarHeader: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer().frame(height: 50)

            // App 图标
            LogoView(variant: .about)
                .frame(width: 64, height: 64)

            // App 名称
            Text(appInfo.name)
                .font(.headline)
                .fontWeight(.semibold)

            // 版本和 Build 信息
            VStack(alignment: .center, spacing: 2) {
                Text("v\(appInfo.version ?? "Unknown")")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("Build \(appInfo.build ?? "Unknown")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer().frame(height: 16)
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
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
