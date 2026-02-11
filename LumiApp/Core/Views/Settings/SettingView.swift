import SwiftUI

/// 设置界面视图，包含侧边栏导航和详情区域
/// 支持 sheet 展示，可通过 dismiss 环境变量关闭
struct SettingView: View {
    /// dismiss 环境，用于关闭 sheet
    @Environment(\.dismiss) private var dismiss

    /// 默认显示的标签
    var defaultTab: SettingTab = .about

    /// 当前选中的标签
    @State private var selectedTab: SettingTab

    /// 设置标签枚举
    enum SettingTab: String, CaseIterable {
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
        self._selectedTab = State(initialValue: defaultTab)
    }

    /// 应用信息
    private var appInfo: AppInfo {
        AppInfo()
    }

    var body: some View {
        NavigationSplitView {
            // 侧边栏
            VStack(spacing: 0) {
                // 应用信息头部
                sidebarHeader

                Divider()

                // 设置列表
                List(SettingTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 200)
        } detail: {
            // 详情区域
            VStack(spacing: 0) {
                // 内容区域
                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettingView()
                    case .theme:
                        ThemeSettingView()
                    case .plugins:
                        PluginSettingsView()
                    case .about:
                        AboutView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 底部完成按钮
                Divider()
                HStack {
                    Spacer()
                    Button("完成") {
                        // 关闭设置视图
                        NotificationCenter.postDismissSettings()
                    }
                    .keyboardShortcut(.defaultAction)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                }
                .background(Color(NSColor.windowBackgroundColor))
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
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
