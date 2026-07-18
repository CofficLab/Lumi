import Foundation

// 类型经 typealias 导出；`Notification.Name` / `View` 扩展无法 typealias，
// 需要 `@_exported` 让只 import LumiCoreKit 的下游模块（插件）继续可见，
// 与这些代码此前直接内嵌在 LumiCoreKit 时的可见性保持一致。
@_exported import LumiComponentProject

// MARK: - Project Component Types

public typealias ProjectComponent = LumiComponentProject.ProjectComponent
public typealias ProjectState = LumiComponentProject.ProjectState
public typealias ProjectEntry = LumiComponentProject.ProjectEntry
public typealias ProjectLanguageDetector = LumiComponentProject.ProjectLanguageDetector
