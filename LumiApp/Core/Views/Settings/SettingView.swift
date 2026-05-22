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

    /// 侧边栏宽度
    private let sidebarWidth: CGFloat = 220

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

    /// 应用信息
    private var appInfo: AppInfo {
        AppInfo()
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
        VStack(spacing: 0) {
            // 应用信息头部
            SettingsSidebarHeaderView()

            settingsDivider

            // 设置列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    // 核心设置项（除"插件管理"外）
                    ForEach(SettingTab.allCases.filter { $0 != .plugins }, id: \.self) { tab in
                        // 在"插件管理"位置前插入可展开的插件分类组
                        if tab == SettingTab(rawValue: "键盘快捷键") {
                            // 键盘快捷键之后插入插件管理
                            SidebarItemView(
                                label: Label(tab.rawValue, systemImage: tab.icon),
                                isSelected: selection == .core(tab)
                            ) {
                                selection = .core(tab)
                            }

                            // 插件管理：可展开的分组节点
                            pluginCategorySection
                        } else {
                            SidebarItemView(
                                label: Label(tab.rawValue, systemImage: tab.icon),
                                isSelected: selection == .core(tab)
                            ) {
                                selection = .core(tab)
                            }
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

    /// 插件管理可展开分组区域
    private var pluginCategorySection: some View {
        VStack(spacing: 0) {
            // "插件管理"父节点
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isPluginCategoryExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.extension")
                        .frame(width: 18)

                    Text("插件管理")

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.appMicroEmphasized)
                        .rotationEffect(.degrees(isPluginCategoryExpanded ? 90 : 0))
                        .foregroundColor(theme.textTertiary)
                }
                .font(.appCaption)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 展开的分类子项
            if isPluginCategoryExpanded {
                ForEach(groupedPlugins, id: \.category) { group in
                    SidebarItemView(
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
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(theme.appDivider)
            .frame(height: 1)
    }

    /// 详情区域视图
    private var detailView: some View {
        ZStack {
            Color.clear
                .mystiqueBackground()
                .ignoresSafeArea()

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
            .background(.background.opacity(0.8))
        }
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
