import LumiUI
import SwiftUI

/// `SettingViewProviding` 的默认实现：持有注入的 `SettingEntryItem`，
/// 渲染为「左侧入口列表 + 右侧详情视图」的设置界面（类似 Lumi 的 SettingsView）。
///
/// 骨架阶段使用：无主题定制，入口为空时显示占位提示；
/// 宿主可注入自己的实现（如基于 SettingsTabItem 的完整设置界面）。
@MainActor
public final class DefaultSettingViewProviding: SettingViewProviding, ObservableObject {
    @Published public private(set) var entries: [SettingEntryItem] = []

    /// 当前选中入口的 id。
    @Published public private(set) var selectedEntryID: String?

    /// 侧边栏顶部的自定义 Header（如 Logo + 应用名），由装配方注入。
    ///
    /// 使用 `AnyView` 注入使 Provider 不感知具体内容类型：宿主（如 FactoryLumi2）
    /// 负责构造 Logo 头部视图，Provider 只负责渲染位置。
    @Published public private(set) var sidebarHeader: AnyView?

    public init() {}

    /// 注入侧边栏顶部 Header（如 Logo + 应用名 + 版本）。
    public func setSidebarHeader(_ view: AnyView?) {
        sidebarHeader = view
    }

    public func registerEntries(_ entries: [SettingEntryItem]) {
        self.entries = entries.sorted { $0.order < $1.order }
        // 保持当前选中；若为空则默认选中第一个。
        if selectedEntryID == nil || !self.entries.contains(where: { $0.id == selectedEntryID }) {
            selectedEntryID = self.entries.first?.id
        }
    }

    /// 选中指定入口。
    public func selectEntry(id: String?) {
        selectedEntryID = id
    }

    public func makeSettingView() -> AnyView {
        AnyView(SettingView(provider: self))
    }
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
private struct SettingView: View {
    @ObservedObject var provider: DefaultSettingViewProviding
    @State private var selectedID: String?
    @LumiTheme private var theme

    init(provider: DefaultSettingViewProviding) {
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
