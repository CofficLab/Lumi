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

    /// 解析项目域记忆的项目路径：优先工具调用所属会话绑定的项目，其次 UI 当前项目。
    ///
    /// 后台回合执行期间用户可能已切到别的项目，只有会话绑定的项目才是这次工具
    /// 调用真正作用的记忆域（#607）。仅当调用缺少会话上下文（旧入口传 `nil`）时
    /// 才回退到当前 UI 项目。
    @MainActor
    static func resolveProjectPath(
        conversationProjectPath: String?,
        capability: MemoryProjectCapability
    ) -> String? {
        if let conversationProjectPath, !conversationProjectPath.isEmpty {
            return conversationProjectPath
        }
        return capability.currentProjectPath
    }
}
