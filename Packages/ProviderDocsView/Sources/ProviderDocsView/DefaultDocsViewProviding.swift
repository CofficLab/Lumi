import SwiftUI

/// `DocsViewProviding` 的默认实现：持有「关于」与「说明书」条目数组。
///
/// 插件通过 `addAbout(_:)` / `addManual(_:)` 追加自己的文档条目；
/// 支持多插件各自贡献（与 `DefaultSettingViewProviding` 追加语义一致）。
@MainActor
public final class DefaultDocsViewProviding: DocsViewProviding {
    public private(set) var aboutEntries: [DocsEntry] = []
    public private(set) var manualEntries: [DocsEntry] = []
    private var observers: [UUID: (DocsViewEvent) -> Void] = [:]

    public init() {}

    @discardableResult
    public func addDocsViewObserver(
        _ callback: @escaping (DocsViewEvent) -> Void
    ) -> any DocsViewObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public func replaceAboutEntries(_ entries: [DocsEntry]) {
        aboutEntries = entries
        notify(.aboutEntriesChanged)
    }

    public func replaceManualEntries(_ entries: [DocsEntry]) {
        manualEntries = entries
        notify(.manualEntriesChanged)
    }

    private func notify(_ event: DocsViewEvent) {
        observers.values.forEach { $0(event) }
    }

    private final class ObserverHandle: DocsViewObserverHandle {
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
