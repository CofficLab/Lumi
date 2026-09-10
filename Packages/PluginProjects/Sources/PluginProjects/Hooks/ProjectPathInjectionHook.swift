import Foundation
import KitLLM
import KitSuperLog
import os
import ProviderLifecycleHooks
import ProviderProject

/// `willSendToLLM` 钩子：将当前项目路径注入 LLM 上下文。
///
/// 未选择项目或项目路径为空时不注入，保持原始上下文不变。
@MainActor
final class ProjectPathInjectionHook: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.projects",
        category: "Projects.Hook"
    )

    private let project: any ProjectProviding

    init(project: any ProjectProviding) {
        self.project = project
    }

    func apply(to context: WillSendToLLMContext) -> WillSendToLLMContext {
        guard let projectPath = project.currentProject?.path,
              !projectPath.isEmpty else {
            Self.logger.error("\(Self.t)无法将当前项目路径注入 LLM 上下文：未选择项目或项目路径为空")
            return context
        }
        var ctx = context
        let projectMessage = LLMMessage(
            role: .system,
            content: "当前工作项目路径：\(projectPath)"
        )
        ctx.messages = [projectMessage] + ctx.messages
        return ctx
    }
}
