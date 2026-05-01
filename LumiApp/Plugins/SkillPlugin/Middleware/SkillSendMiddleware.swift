import Foundation
import MagicKit
import os

/// Skill 上下文注入中间件
///
/// 在每次发送用户消息前，扫描当前项目的 `.agent/skills/` 目录，
/// 将可用 Skill 的摘要注入 `transientSystemPrompts`，让 LLM 感知并使用。
///
/// ## 工作流程
/// 1. 拦截用户消息发送
/// 2. 从上下文获取当前项目路径
/// 3. 调用 SkillService 获取可用 Skill 列表
/// 4. 将 Skill 摘要格式化为系统提示词
/// 5. 注入到 transientSystemPrompts 中
///
/// ## 设计决策
/// - 仅注入元数据摘要（名称、描述），控制 Token 消耗
/// - LLM 看到摘要后自主决定是否使用
/// - 如果目录不存在或为空，静默跳过，不阻塞发送流程
@MainActor
final class SkillSendMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "✨"
    nonisolated static let verbose: Bool = false
    let id: String = "skill-context"
    let order: Int = 50

    // MARK: - 执行

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        // 未选择项目时跳过
        guard !projectPath.isEmpty else {
            await next(ctx)
            return
        }

        // 获取可用 Skill 列表
        let skills = await SkillService.shared.listSkills(projectPath: projectPath)

        // 无 Skill 时跳过
        guard !skills.isEmpty else {
            await next(ctx)
            return
        }

        // 构建 Prompt 并注入
        let prompt = buildSkillPrompt(skills: skills)
        ctx.transientSystemPrompts.append(prompt)

        if Self.verbose {
            SkillPlugin.logger.info("\(Self.t)✅ 已注入 \(skills.count) 个 Skill 摘要")
        }

        await next(ctx)
    }

    // MARK: - 提示词构建

    /// 将 Skill 列表格式化为系统提示词
    private func buildSkillPrompt(skills: [SkillMetadata]) -> String {
        var lines: [String] = []

        lines.append("## Available Skills")
        lines.append("")
        lines.append("You have access to the following specialized skills. If the user's request matches a skill, follow its instructions and guidelines.")
        lines.append("")
        lines.append("| Skill | Description |")
        lines.append("|-------|-------------|")

        for skill in skills {
            let escapedDescription = skill.description
                .replacingOccurrences(of: "|", with: "\\|")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            lines.append("| `\(skill.name)` | \(escapedDescription) |")
        }

        lines.append("")
        lines.append("When using a skill, start your response with: `[Skill: <skill-name>]` to indicate activation.")

        return lines.joined(separator: "\n")
    }
}
