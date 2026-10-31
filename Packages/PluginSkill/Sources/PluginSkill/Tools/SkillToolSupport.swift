import Foundation
import KitAgentTool

/// Skill 工具共享：解析公共参数。
///
/// 让 list / read / update / delete 工具共用同一套「项目路径回退 + 参数清理」逻辑，
/// 避免四个工具各写一份略有差异的解析代码。
enum SkillToolSupport {

    /// 解析项目路径：显式 `project_path` 优先，否则回退当前项目。
    ///
    /// 两者都拿不到时返回 `nil`，由调用方决定抛错还是返回空结果。
    static func resolveProjectPath(
        _ arguments: [String: ToolArgument]
    ) async -> String? {
        let explicit = string(arguments, "project_path")
        if let explicit, !explicit.isEmpty { return explicit }
        let current = await MainActor.run { SkillRuntime.currentProjectPath }
        guard let current, !current.isEmpty else { return nil }
        return current
    }

    /// 读取并清理字符串参数；空字符串视为未提供。
    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        guard let raw = (arguments[key]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }

    /// 读取字符串数组参数（如 `triggers`），逐项去空白，过滤空值。
    ///
    /// 返回 `nil` 表示参数缺失；返回空数组表示「显式传入空数组」，
    /// 调用方据此区分「保持原值」与「清空」。
    static func stringArrayAllowingEmpty(
        _ arguments: [String: ToolArgument],
        _ key: String
    ) -> [String]? {
        guard let raw = arguments[key]?.value as? [String] else { return nil }
        return raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// 读取整型参数，兼容 JSON 里出现的 Double / 字符串写法。
    static func int(_ arguments: [String: ToolArgument], _ key: String) -> Int? {
        if let value = arguments[key]?.value as? Int { return value }
        if let value = arguments[key]?.value as? Double { return Int(value) }
        if let value = arguments[key]?.value as? String { return Int(value) }
        return nil
    }
}
