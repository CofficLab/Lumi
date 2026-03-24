import SwiftUI

/// 设置界面视图，使用 HStack 实现左右并排布局
struct SettingView: View {
    /// 插件 VM
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var themeManager: ThemeManager

    /// 默认显示的标签
    var defaultTab: SettingTab = .about

    /// 当前选中的项
    @State private var selection: SettingsSelection?

    /// 侧边栏宽度
    private let sidebarWidth: CGFloat = 220

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

    /// 侧边栏内容视图
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // 应用信息头部
            SettingsSidebarHeaderView()

            GlassDivider()

            // 设置列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    // 核心设置项
                    ForEach(SettingTab.allCases, id: \.self) { tab in
                        SidebarItemView(
                            label: Label(tab.rawValue, systemImage: tab.icon),
                            isSelected: selection == .core(tab)
                        ) {
                            selection = .core(tab)
                        }
                    }

                    // 插件设置项
                    if !pluginSettings.isEmpty {
                        Divider()
                            .padding(.vertical, 8)

                        ForEach(pluginSettings, id: \.id) { item in
                            SidebarItemView(
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
        .padding()
        .frame(width: sidebarWidth)
        .background(.background.opacity(0.6))
    }

    /// 详情区域视图
    private var detailView: some View {
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
                }
            } else {
                Text("请选择设置项")
                    .foregroundColor(.secondary)
            }
        }
        .background(.background.opacity(0.8))
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧侧边栏
            sidebarView

            // 垂直分割线
            Divider()

            // 右侧详情区域
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
