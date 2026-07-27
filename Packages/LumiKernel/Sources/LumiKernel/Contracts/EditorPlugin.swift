import Foundation

/// 编辑器插件协议。
///
/// 编辑器相关的功能扩展（如 Swift 语言支持、Markdown 语法等）通过实现此协议，
/// 在 `registerExtensions(into:)` 中把语言、语法、主题等扩展注册进编辑器运行时。
///
/// 设计上，编辑器插件**面向 `EditorProviding` 注册**，而不直接依赖具体编辑器实现，
/// 从而保持编辑器能力与内核之间的解耦：内核只认识 `EditorProviding` 与 `EditorPlugin`，
/// 具体编辑器（EditorService）由编辑器插件宿主在边界处桥接。
@MainActor
public protocol EditorPlugin: AnyObject {
    /// 插件唯一标识。
    var id: String { get }

    /// 插件展示名称。
    var name: String { get }

    /// 注册顺序，数值越小越先注册。
    var order: Int { get }

    /// 把本插件提供的扩展写入 host 提供的注册器。
    ///
    /// - Parameter registrar: 编辑器运行时扩展注册器；具体实现为编辑器内部的扩展注册表。
    func registerExtensions(into registrar: any EditorExtensionRegistrar)
}

/// 编辑器扩展注册器。
///
/// 由 `EditorProviding` 的具体实现桥接到编辑器运行时的扩展注册表。
/// 这里只暴露**内核可见（不依赖 EditorService）**的扩展类型，
/// 以避免 `LumiKernel` 与编辑器实现层之间产生依赖环。
///
/// 当前仅覆盖语言与语法两类最基础的扩展；其余贡献点（高亮、补全、悬停等）
/// 后续可在本协议上按需扩展，或经由编辑器内部注册表直接桥接。
@MainActor
public protocol EditorExtensionRegistrar: AnyObject {
    /// 注册语言描述符，用于文件类型识别与高亮语言判定。
    func registerLanguage(_ descriptor: EditorLanguageDescriptor)

    /// 注册语法提供器（如 tree-sitter），用于产生高亮 token。
    func registerGrammarProvider(_ provider: any LanguageGrammarProviding)
}
