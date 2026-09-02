import Foundation
import KitAgentTool
import ProviderProject

/// Git 工具名称清单：LLM 可调用的全部 Git 工具。
enum GitV2ToolNames {
    static let all = ["git_status", "git_diff", "git_log", "git_show", "git_branch", "git_commit", "git_unpushed"]
}

/// Git V2 工具共享支持：参数读取、路径解析、JSON Schema 构造。
enum GitV2ToolSupport {
    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        guard let value = arguments[key]?.value else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    static func bool(_ arguments: [String: ToolArgument], _ key: String) -> Bool? {
        guard let value = arguments[key]?.value else { return nil }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String { return Bool(string) }
        return nil
    }

    static func int(_ arguments: [String: ToolArgument], _ key: String) -> Int? {
        guard let value = arguments[key]?.value else { return nil }
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) }
        return nil
    }

    static func strings(_ arguments: [String: ToolArgument], _ key: String) -> [String] {
        guard let value = arguments[key]?.value else { return [] }
        if let strings = value as? [String] { return strings }
        if let values = value as? [Any] { return values.compactMap { $0 as? String } }
        return []
    }

    @MainActor
    static func path(_ arguments: [String: ToolArgument], project: (any ProjectProviding)?) throws -> String {
        let requested = string(arguments, "path")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = requested?.isEmpty == false
            ? requested
            : project?.currentProject?.path
        return try GitService.validatePath(candidate, allowedDirectories: [])
    }

    static func schema(_ properties: [String: Any], required: [String] = []) -> [String: Any] {
        var schema: [String: Any] = ["type": "object", "properties": properties, "additionalProperties": false]
        if !required.isEmpty { schema["required"] = required }
        return schema
    }

    static func pathProperty() -> [String: Any] {
        ["type": "string", "description": "Git repository path, defaults to the current project directory."]
    }
}