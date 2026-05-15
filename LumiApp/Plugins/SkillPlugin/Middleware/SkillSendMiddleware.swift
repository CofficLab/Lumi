import Foundation
import MagicKit
import SkillKit
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
    nonisolated static let verbose: Bool = true
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

        let language = ctx.projectVM.languagePreference.skillPromptLanguage

        // 获取可用 Skill 列表并构建 Prompt。发送管线本身运行在 MainActor，
        // 这里显式放到后台任务中，避免缓存过期时的文件系统扫描和字符串构建占用 UI 线程。
        let result = await Task.detached(priority: .userInitiated) {
            let skills = await SkillService.shared.listSkills(projectPath: projectPath)
            guard !skills.isEmpty else {
                return (skills: skills, prompt: nil as String?)
            }

            let prompt = SkillPromptBuilder.buildPrompt(
                skills: skills,
                language: language
            )
            return (skills: skills, prompt: prompt)
        }.value

        // 无 Skill 时跳过
        guard let prompt = result.prompt else {
            await next(ctx)
            return
        }
        ctx.transientSystemPrompts.append(prompt)

        if Self.verbose {
            SkillPlugin.logger.info("\(Self.t)✅ 已注入 \(result.skills.count) 个 Skill 摘要")
        }

        await next(ctx)
    }
}

private extension LanguagePreference {
    var skillPromptLanguage: SkillPromptLanguage {
        switch self {
        case .chinese:
            return .chinese
        case .english:
            return .english
        }
    }
}
