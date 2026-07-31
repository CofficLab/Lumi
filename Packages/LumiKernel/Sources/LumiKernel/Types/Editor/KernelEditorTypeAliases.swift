import Foundation

/// 内核侧编辑器类型的 Kernel 前缀别名。
///
/// 供 EditorService 桥接层使用，避免 `LumiKernel` 模块名与 `typealias LumiKernel = LumiKernelContainer`
/// 的名字冲突，同时也避免 EditorService 同时导入 `LumiKernel` 和 `EditorLanguageRuntime` 时
/// 同名类型的歧义。
public typealias KernelEditorLanguageDescriptor = EditorLanguageDescriptor

/// 内核侧 `LanguageGrammarProviding` 的 Kernel 前缀别名。用途同上。
public typealias KernelLanguageGrammarProviding = LanguageGrammarProviding
