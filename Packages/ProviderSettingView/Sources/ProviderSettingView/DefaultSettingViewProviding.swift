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
