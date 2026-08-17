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

    public init() {}

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
