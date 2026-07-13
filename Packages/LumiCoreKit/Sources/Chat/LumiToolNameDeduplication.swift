import Foundation

/// 工具名去重校验
public enum LumiToolNameDeduplication {
    /// 校验并报错重复工具名
    public static func assertUnique(tools: [any LumiAgentTool]) {
        var seen: [String: (any LumiAgentTool)] = [:]

        for tool in tools {
            if let existing = seen[tool.name] {
                let existingType = String(describing: type(of: existing))
                let newType = String(describing: type(of: tool))
                fatalError("Duplicate tool name '\(tool.name)': existing=\(existingType), new=\(newType)")
            }
            seen[tool.name] = tool
        }
    }
}
