import SwiftUI
import LumiUI

/// 公开工厂函数：为任意 `SettingViewProviding & ObservableObject` 实现渲染设置界面。
///
/// 供 `PluginSettingView` 等自定义 Provider 在 `makeSettingView()` 中复用
/// 与 `DefaultSettingViewProviding` 完全一致的视图。
public func makeSettingView<Provider: SettingViewProviding & ObservableObject>(
    provider: Provider
) -> AnyView {
    AnyView(SettingView(provider: provider))
}

/// 渲染「左侧入口列表 + 右侧详情视图」的设置界面。
///
/// 完整复刻旧版 Lumi（`FactoryCore.SettingsView`）的视觉与交互：
/// - `AppSettingsSidebarShell` 双栏布局：固定宽侧边栏 + 分隔线 + 详情区
/// - 侧边栏半透明背景（`AppSettingsSidebarContainer`）、详情区氛围渐变
///   （`AppSettingsDetailPane`）
/// - 窗口背景为主题氛围深色（`theme.background`）、强制主题明暗外观、
///   同步 AppKit 窗口外观（与旧版完全一致）
/// - 最小尺寸 720 × 520，空状态与旧版一致（gearshape + "Select a tab"）
///
/// 泛型 `Provider` 支持任意 `SettingViewProviding & ObservableObject` 实现，
/// 使 `PluginSettingView` 等自定义 Provider 也可复用同一视图。
struct SettingView<Provider: SettingViewProviding & ObservableObject>: View {
    @ObservedObject var provider: Provider
    @State private var selectedID: String?
    @LumiTheme private var theme

    init(provider: Provider) {
        self.provider = provider
        _selectedID = State(initialValue: provider.selectedEntryID)
    }

    var body: some View {
        AppSettingsSidebarShell { sidebar } detail: { detail }
            .frame(minWidth: 720, minHeight: 520)
            .background(theme.background)
            .appThemedAppearance()
        #if canImport(AppKit)
            .background {
                ThemeWindowAppearanceBridge()
            }
        #endif
            .ignoresSafeArea()
    }

    /// 左侧：注入的顶部 Header（Logo + 应用名）+ 入口列表。
    private var sidebar: some View {
        AppSettingsSidebarContainer(width: 220) {
            VStack(alignment: .leading, spacing: 10) {
                if let header = provider.sidebarHeader {
                    header
                    AppSettingsDivider()
                }

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(provider.entries) { entry in
                            AppSettingsSidebarItem(
                                title: entry.title,
                                systemImage: entry.systemImage,
                                isSelected: (selectedID ?? provider.selectedEntryID) == entry.id
                            ) {
                                selectedID = entry.id
                                provider.selectEntry(id: entry.id)
                            }
                        }
                    }
                    .padding(.leading)
                }

                Spacer()
            }
        }
    }

    /// 右侧：详情视图（氛围渐变背景），无选中时显示与旧版一致的空状态。
    private var detail: some View {
        AppSettingsDetailPane {
            Group {
                if let selected = provider.entries.first(where: { $0.id == selectedID ?? provider.selectedEntryID }) {
                    selected.makeDetailView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AppEmptyState(
                        icon: "gearshape",
                        title: "Select a tab"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
