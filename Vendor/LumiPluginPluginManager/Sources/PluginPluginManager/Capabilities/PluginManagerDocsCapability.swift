import ProviderDocsView

/// Plugin Manager 需要的最小文档能力边界。
///
/// ViewModel 只按插件 ID 读取 About 条目，不需要注册 / 移除 / 事件订阅能力
/// （注册与移除由插件入口负责）。
@MainActor
protocol PluginManagerDocsCapability: AnyObject {
    /// 查询指定插件的 About 条目；未注册时返回 `nil`。
    func aboutEntry(for pluginID: String) -> DocsEntry?
}

/// 将内核的 `DocsViewProviding` 收窄为 Plugin Manager 的文档查询能力。
@MainActor
final class PluginManagerDocsCapabilityAdapter: PluginManagerDocsCapability {
    private let docs: (any DocsViewProviding)?

    init(docs: (any DocsViewProviding)?) {
        self.docs = docs
    }

    func aboutEntry(for pluginID: String) -> DocsEntry? {
        docs?.aboutEntries.first { $0.id == pluginID }
    }
}
