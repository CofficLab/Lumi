import os
import LumiKernel

/// Swift 插件日志辅助（插件内共享）
public enum SwiftPluginLog {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.swift")
    nonisolated(unsafe) static var verbose: Bool = true
}

/// Swift editor runtime contribution exposed through LumiKernel's typed editor plugin API.
@MainActor
public final class EditorSwiftEditorPlugin: EditorPlugin {
    public let id = "EditorSwift.language"
    public let name = "Swift Language Support"
    public let order = 4

    public init() {}

    public func registerExtensions(into registrar: any EditorExtensionRegistrar) {
        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("开始注册编辑器扩展")
        }

        registrar.registerLanguage(EditorSwiftPluginDescriptor.swift)
        registrar.registerGrammarProvider(EditorSwiftGrammarProvider())

        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("编辑器扩展注册完成")
        }
    }
}
