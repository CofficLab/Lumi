import Foundation

/// 编辑器贡献宿主能力（契约 V2，见重构方案 §9.1）。
///
/// 由 `EditorHostPlugin` 实现并通过 `EditorProviding.extensions` 暴露。
/// 贡献包按插件维度**原子安装/替换/撤回**；一个插件失败只影响自己。
@MainActor
public protocol EditorContributionProviding: AnyObject {
    /// 同步安装/替换贡献包，供插件启动阶段使用。
    ///
    /// 该操作在 Host 的主 actor 上完成，安装失败时保持原有贡献不变。
    func installBundle(for pluginID: String, with bundle: EditorContributionBundle?) throws

    /// 原子安装/替换某插件的贡献包。
    ///
    /// - Parameter bundle: 已由 PluginManager 盖戳（pluginID/generation）的贡献包；
    ///   传 `nil` 表示撤回该插件的全部贡献。
    /// - Throws: `EditorContractError.invalidWorkspaceEdit` 同族语义——
    ///   API 版本不兼容、内部 id 重复等校验失败时抛出，且**不改变**现有安装状态。
    func replaceBundle(for pluginID: String, with bundle: EditorContributionBundle?) async throws

    /// 查询某能力对某文档的可用性（§9.5 解析策略的统一出口）。
    func availability(for feature: EditorFeature, document: EditorDocumentSummary) -> EditorFeatureAvailability
}

/// 迁移期间保留的兼容名称。
@available(*, deprecated, renamed: "EditorContributionProviding")
public typealias EditorExtensionHosting = EditorContributionProviding
