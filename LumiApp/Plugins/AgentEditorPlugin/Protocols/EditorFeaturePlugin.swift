import Foundation

/// 编辑器内部插件协议。
///
/// @deprecated Phase 5: 所有编辑器插件已迁移到 `SuperPlugin` 协议。
/// 请使用 `actor XXX: SuperPlugin` + `providesEditorExtensions` 替代。
@available(*, deprecated, message: "Use SuperPlugin with providesEditorExtensions instead")
@MainActor
protocol EditorFeaturePlugin: AnyObject {
    /// 唯一标识
    var id: String { get }
    /// 展示名称
    var displayName: String { get }
    /// 功能描述
    var description: String { get }
    /// 注册顺序（越小越先注册）
    var order: Int { get }
    /// 是否允许用户开关
    var isConfigurable: Bool { get }
    /// 默认是否启用
    var isEnabledByDefault: Bool { get }

    /// 向编辑器扩展注册中心注入能力
    func register(into registry: EditorExtensionRegistry)
}

extension EditorFeaturePlugin {
    var isConfigurable: Bool { true }
    var isEnabledByDefault: Bool { true }
}
