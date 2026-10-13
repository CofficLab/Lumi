import ProviderDocsView

/// 通用设置页需要的最小说明书能力。
@MainActor
protocol GeneralSettingsDocsCapability: AnyObject {
    /// 所有提供了说明书的文档条目。
    var manuals: [DocsEntry] { get }

    @discardableResult
    func addDocsViewObserver(
        _ callback: @escaping (DocsViewEvent) -> Void
    ) -> (any DocsViewObserverHandle)?
}

/// 默认实现：把 `DocsViewProviding` 收窄为本插件的说明书能力。
@MainActor
final class GeneralSettingsDocsCapabilityAdapter: GeneralSettingsDocsCapability {
    private let docsProvider: (any DocsViewProviding)?

    init(docsProvider: (any DocsViewProviding)?) {
        self.docsProvider = docsProvider
    }

    var manuals: [DocsEntry] {
        docsProvider?.manualEntries ?? []
    }

    @discardableResult
    func addDocsViewObserver(
        _ callback: @escaping (DocsViewEvent) -> Void
    ) -> (any DocsViewObserverHandle)? {
        docsProvider?.addDocsViewObserver(callback)
    }
}