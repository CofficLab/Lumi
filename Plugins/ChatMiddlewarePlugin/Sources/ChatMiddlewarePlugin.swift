import Foundation
import LumiCoreKit
import SkillKit

public enum ChatMiddlewareRuntime {
    public static let currentProjectPath = ProjectPathStorage()
}

public final class ProjectPathStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var path = ""

    public var value: String {
        lock.lock()
        defer { lock.unlock() }
        return path
    }

    public func set(_ newValue: String) {
        lock.lock()
        path = newValue
        lock.unlock()
    }
}

public enum ChatMiddlewarePlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-middleware",
        displayName: "Chat Middleware",
        description: "Inject skills and project context into chat sends.",
        order: 45
    )
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "arrow.triangle.branch"

    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [
            AgentRulesChatMiddleware(),
            MemoryChatMiddleware(),
            SkillChatMiddleware(),
            RAGChatMiddleware(),
            ConversationHintMiddleware(),
            RequestLogChatMiddleware()
        ]
    }
}

struct SkillChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let projectPath = ChatMiddlewareRuntime.currentProjectPath.value.trimmingCharacters(in: .whitespacesAndNewlines)
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

struct ConversationHintMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let projectPath = ChatMiddlewareRuntime.currentProjectPath.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !projectPath.isEmpty {
            updated.systemPromptFragments.append("Current project path: \(projectPath)")
        }
        return updated
    }
}
