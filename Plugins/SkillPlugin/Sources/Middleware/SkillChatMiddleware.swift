import Foundation
import LumiCoreKit

struct SkillChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let projectPath = context.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else {
            return updated
        }

        let skills = await SkillService.shared.listSkills(projectPath: projectPath)
        guard !skills.isEmpty else {
            return updated
        }

        let prompt = SkillPromptBuilder.buildPrompt(skills: skills, language: .chinese)
        guard !prompt.isEmpty else {
            return updated
        }

        updated.systemPromptFragments.append(prompt)
        return updated
    }
}
