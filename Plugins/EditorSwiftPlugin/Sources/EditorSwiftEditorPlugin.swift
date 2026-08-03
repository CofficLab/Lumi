import LumiKernel
import os

/// Swift 插件日志辅助（插件内共享）
public enum SwiftPluginLog {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.swift")
    nonisolated(unsafe) static var verbose: Bool = false
}

/// Swift editor runtime contribution exposed through LumiKernel's typed editor plugin API.
@MainActor
public final class EditorSwiftEditorPlugin: EditorPlugin {
    public let id = "EditorSwift.language"
    public var name: String {
        LumiPluginLocalization.string("Swift Language Support", bundle: .module)
    }
    public let order = 4

    public init() {}

    public func registerExtensions(into registrar: any EditorExtensionRegistrar) {
        registrar.registerLanguage(EditorSwiftPluginDescriptor.swift)
        registrar.registerGrammarProvider(EditorSwiftGrammarProvider())
    }
}
