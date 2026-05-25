import Foundation

/// 编辑器扩展注册中心协议
///
/// LumiCoreKit 通过此协议与 EditorService 解耦。
/// 内核的 EditorExtensionRegistry 需遵循此协议。
/// 编辑器插件通过 `registerEditorExtensions(into:)` 接收此协议实现并注册能力。
@MainActor
public protocol EditorExtensionRegistryProtocol: AnyObject {
    /// 编辑器扩展注册中心的基础占位方法
    ///
    /// 具体的注册方法由 EditorExtensionRegistry 在遵循协议时提供。
    /// 插件在 `registerEditorExtensions(into:)` 中将参数强转为
    /// `EditorService.EditorExtensionRegistry` 来使用完整 API。
    ///
    /// 这种设计允许 LumiCoreKit 不直接依赖 EditorService（及其沉重的编辑器依赖链），
    /// 同时保持类型安全。
}

// MARK: - Editor Extension Points Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供编辑器扩展能力
    nonisolated public var providesEditorExtensions: Bool { false }

    /// 默认实现：不向编辑器扩展注册中心注入任何能力
    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {}
}
