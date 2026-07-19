import Foundation
import LumiKernel
import SuperLogKit

struct SkillChatMiddleware: LumiSendMiddleware, SuperLog {
    nonisolated static let emoji = "✨"
    nonisolated static let verbose = false
    
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let projectPath = context.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else {
            if Self.verbose {
                SkillPlugin.logger.info("\(Self.t)项目路径为空，跳过 Skill 注入")
            }
            return updated
        }

        if Self.verbose {
            SkillPlugin.logger.info("\(Self.t)开始加载 Skill，项目：\(projectPath)")
        }
        
        let skills = await SkillService.shared.listSkills(projectPath: projectPath)
        guard !skills.isEmpty else {
            if Self.verbose {
                SkillPlugin.logger.info("\(Self.t)未找到 Skill")
            }
            return updated
        }

        let prompt = SkillPromptBuilder.buildPrompt(skills: skills, language: .chinese)
        guard !prompt.isEmpty else {
            if Self.verbose {
                SkillPlugin.logger.info("\(Self.t)构建的 prompt 为空")
            }
            return updated
        }

        if Self.verbose {
            SkillPlugin.logger.info("\(Self.t)成功注入 \(skills.count) 个 Skill 到上下文")
        }
        updated.systemPromptFragments.append(prompt)
        return updated
    }
}
