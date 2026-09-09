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
    @Published public private(set) var projectDetailSections: [ProjectDetailSectionItem] = []

    /// 当前选中入口的 id。
    @Published public private(set) var selectedEntryID: String?
    private var observers: [UUID: (SettingViewEvent) -> Void] = [:]

    public init() {}

    @discardableResult
    public func addSettingViewObserver(
        _ callback: @escaping (SettingViewEvent) -> Void
    ) -> any SettingViewObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public func registerEntries(_ entries: [SettingEntryItem]) {
        let previousSelectedEntryID = selectedEntryID
        self.entries = entries.sorted { $0.order < $1.order }
        // 保持当前选中；若为空则默认选中第一个。
        if selectedEntryID == nil || !self.entries.contains(where: { $0.id == selectedEntryID }) {
            selectedEntryID = self.entries.first?.id
        }
        notify(.entriesChanged)
        if previousSelectedEntryID != selectedEntryID {
            notify(.selectedEntryChanged(selectedEntryID))
        }
    }

    /// 选中指定入口。
    public func selectEntry(id: String?) {
        guard selectedEntryID != id else { return }
        selectedEntryID = id
        notify(.selectedEntryChanged(id))
    }

    public func makeSettingView() -> AnyView {
        AnyView(SettingView(provider: self))
    }

    public func addProjectDetailSections(_ newSections: [ProjectDetailSectionItem]) {
        var merged = projectDetailSections
        for section in newSections where !merged.contains(where: { $0.id == section.id }) {
            merged.append(section)
        }
        projectDetailSections = merged.sorted { $0.order < $1.order }
        notify(.projectDetailSectionsChanged)
    }

    public func removeProjectDetailSections(ids: Set<String>) {
        projectDetailSections.removeAll { ids.contains($0.id) }
        notify(.projectDetailSectionsChanged)
    }

    private func notify(_ event: SettingViewEvent) {
        observers.values.forEach { $0(event) }
    }

    private final class ObserverHandle: SettingViewObserverHandle {
        private var cancellation: (() -> Void)?

        init(cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        func cancel() {
            cancellation?()
            cancellation = nil
        }
    }
}
