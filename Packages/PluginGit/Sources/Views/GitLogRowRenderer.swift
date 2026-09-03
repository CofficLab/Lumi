import AppKit
import KitAgentTool
import LumiUI
import ProviderMessageRendering
import SwiftUI

/// git_log 工具结果的专用行渲染器：在消息列表中把 commit 历史渲染为卡片列表。
///
/// 数据流：
/// 1. LLM 调用 `git_log`，`GitLogTool.execute` 返回人类可读文本 + 末尾 JSON 代码块；
/// 2. 本渲染器命中 `canRender`（工具名匹配且结果含 JSON 块），从
///    `ToolCallResult.content` 提取 JSON 并解码为 `[GitCommitLog]`；
/// 3. 渲染 `GitLogCardList`；任何解析失败都回退到默认工具文本视图。
public struct GitLogRowRenderer: ToolCallRowRenderer {
    public static let id = "git-log-row"
    public static let priority = 110

    public init() {}

    /// 命中条件：git_log 工具，且返回内容包含可解析的 JSON 代码块。
    public func canRender(toolCall: ToolCall) -> Bool {
        guard toolCall.name == GitLogTool.toolName,
              let content = toolCall.result?.content else {
            return false
        }
        return Self.extractJSON(from: content) != nil
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let content = toolCall.result?.content,
              let json = Self.extractJSON(from: content),
              let data = json.data(using: .utf8),
              let commits = try? JSONDecoder().decode([GitCommitLog].self, from: data),
              !commits.isEmpty else {
            // 回退：仍然展示工具返回的原始文本，避免信息丢失。
            return AnyView(
                Text(toolCall.result?.content ?? "Git 提交历史")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            )
        }

        return AnyView(GitLogCardList(commits: commits))
    }

    /// 从工具返回内容中提取第一个 ```json ... ``` 代码块的内容。
    static func extractJSON(from content: String) -> String? {
        let marker = "```json"
        guard let start = content.range(of: marker)?.upperBound else { return nil }
        let rest = content[start...]
        guard let end = rest.range(of: "```")?.lowerBound else { return nil }
        let json = rest[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return json.isEmpty ? nil : json
    }
}