import Foundation

/// 工具名称去重断言工具
///
/// 确保注册的工具列表中没有重名工具。
/// 重复的工具名会导致工具调用歧义，在注册阶段应被拦截。
public enum LumiToolNameDeduplication {
    /// 断言工具列表中的名称唯一，重复时 fatalError。
    public static func assertUnique(tools: [any LumiAgentTool]) {
        var seen = Set<String>()
        var duplicates: Set<String> = []
        for tool in tools {
            if !seen.insert(tool.name).inserted {
                duplicates.insert(tool.name)
            }
        }
        if !duplicates.isEmpty {
            let names = duplicates.sorted().joined(separator: ", ")
            fatalError("工具名称重复: \(names)")
        }
    }
}
