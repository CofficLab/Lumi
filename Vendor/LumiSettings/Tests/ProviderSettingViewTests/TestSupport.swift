import SwiftUI
@testable import ProviderSettingView

// MARK: - Event Log

/// 记录 Provider 发布的事件顺序，供断言使用。
@MainActor
final class EventLog {
    private(set) var labels: [String] = []

    static func label(for event: SettingViewEvent) -> String {
        switch event {
        case .entriesChanged: "entries"
        case .projectDetailSectionsChanged: "sections"
        case let .selectedEntryChanged(id): "selected:\(id ?? "nil")"
        }
    }

    /// 订阅 Provider 并返回句柄；日志随 Provider 一起释放，避免测试残留观察者。
    func observe(_ provider: some SettingViewProviding) -> any SettingViewObserverHandle {
        provider.addSettingViewObserver { [weak self] event in
            self?.labels.append(Self.label(for: event))
        }
    }
}

// MARK: - Minimal Provider

/// 只实现协议必需成员的 Provider，用于验证协议扩展的默认实现。
@MainActor
final class MinimalSettingViewProvider: SettingViewProviding {
    private(set) var entries: [SettingEntryItem] = []
    private(set) var registerCallCount = 0

    func registerEntries(_ entries: [SettingEntryItem]) {
        registerCallCount += 1
        self.entries = entries
    }

    func makeSettingView() -> AnyView {
        AnyView(Text("minimal settings"))
    }
}

// MARK: - Fixtures

@MainActor
enum EntryFixture {
    static func entry(
        _ id: String,
        title: String? = nil,
        systemImage: String = "gearshape",
        order: Int = 200
    ) -> SettingEntryItem {
        SettingEntryItem(id: id, title: title ?? id.uppercased(), systemImage: systemImage, order: order) {
            Text("\(id) detail")
        }
    }
}

@MainActor
enum SectionFixture {
    static func section(_ id: String, order: Int = 200) -> ProjectDetailSectionItem {
        ProjectDetailSectionItem(id: id, order: order) { path in
            Text("\(id) section for \(path)")
        }
    }
}
