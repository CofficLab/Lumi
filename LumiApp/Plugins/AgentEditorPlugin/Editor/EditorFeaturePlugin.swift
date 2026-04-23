import Foundation

/// 编辑器内部插件协议。
///
/// 这是一层“编辑器子插件”能力，用于承载适合插件化的编辑器功能
/// （补全、hover、code action 等），避免所有能力都耦合在 EditorState 中。
@MainActor
protocol EditorFeaturePlugin: AnyObject {
    /// 唯一标识
    var id: String { get }
    /// 展示名称
    var displayName: String { get }
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
