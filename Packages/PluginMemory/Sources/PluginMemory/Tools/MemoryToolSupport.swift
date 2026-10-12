import Foundation
import KitAgentTool

/// 记忆工具共享：解析 scope/type/projectPath 参数。
enum MemoryToolSupport {
    static func scope(_ arguments: [String: ToolArgument]) -> MemoryScope {
        guard let raw = arguments["scope"]?.value as? String else { return .global }
        return MemoryScope(rawValue: raw) ?? .global
    }

    static func type(_ arguments: [String: ToolArgument]) -> MemoryType? {
        guard let raw = arguments["type"]?.value as? String else { return nil }
        return MemoryType(rawValue: raw)
    }

    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        (arguments[key]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
