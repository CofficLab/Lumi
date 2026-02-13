import SwiftUI

/// 设置界面视图，包含侧边栏导航和详情区域
/// 支持 sheet 展示，可通过 dismiss 环境变量关闭
struct SettingView: View {
    /// dismiss 环境，用于关闭 sheet
    @Environment(\.dismiss) private var dismiss

    /// 插件提供者
    @ObservedObject private var pluginProvider = PluginProvider.shared

    /// 默认显示的标签
    var defaultTab: SettingTab = .about

    /// 设置选择枚举
    enum SettingsSelection: Hashable {
        case core(SettingTab)
        case plugin(String)
    }

    /// 当前选中的项
    @State private var selection: SettingsSelection?

    /// 设置标签枚举
    enum SettingTab: String, CaseIterable, Hashable {
        case general = "通用"
        case theme = "主题"
        case plugins = "插件管理"
        case about = "关于"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .theme: return "paintbrush.fill"
            case .plugins: return "puzzlepiece.extension"
            case .about: return "info.circle"
            }
        }
    }

    /// 初始化方法
    /// - Parameter defaultTab: 默认选中的标签
    init(defaultTab: SettingTab = .about) {
        self.defaultTab = defaultTab
        self._selection = State(initialValue: .core(defaultTab))
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
        NavigationSplitView {
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
            .navigationSplitViewColumnWidth(min: 150, ideal: 200)
        } detail: {
            // 详情区域
            VStack(spacing: 0) {
                // 内容区域
                Group {
                    if let sel = selection {
                        switch sel {
                        case .core(let tab):
                            switch tab {
                            case .general:
                                GeneralSettingView()
                            case .theme:
                                ThemeSettingView()
                            case .plugins:
                                PluginSettingsView()
                            case .about:
                                AboutView()
                            }
                        case .plugin(let id):
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 底部完成按钮
                GlassDivider()
                HStack {
                    Spacer()
                    GlassButton(title: "完成", style: .primary) {
                        // 关闭设置视图
                        NotificationCenter.postDismissSettings()
                    }
                    .keyboardShortcut(.defaultAction)
                    .frame(width: 120)
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Material.glass)
            }
        }
        .frame(width: 700, height: 800)
        .onDismissSettings{
            dismiss()
        }
    }

    // MARK: - View

    /// 侧边栏头部 - 应用信息
    private var sidebarHeader: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer().frame(height: 20)

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
        .frame(maxWidth: .infinity)
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
