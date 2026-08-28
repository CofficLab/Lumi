import Foundation

/// 内核侧编辑器类型的 Kernel 前缀别名。
///
/// 供 EditorService 桥接层使用，避免 `KernelLumi` 模块名与 `typealias KernelLumi = KernelLumiContainer`
/// 的名字冲突，同时也避免 EditorService 同时导入 `KernelLumi` 和 `EditorLanguageRuntime` 时
/// 同名类型的歧义。
public typealias KernelEditorLanguageDescriptor = EditorLanguageDescriptor

/// 内核侧 `LanguageGrammarProviding` 的 Kernel 前缀别名。用途同上。
public typealias KernelLanguageGrammarProviding = LanguageGrammarProviding
