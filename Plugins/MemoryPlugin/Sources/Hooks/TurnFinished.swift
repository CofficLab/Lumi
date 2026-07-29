import Foundation
import LumiKernel

/// Memory 插件 turn finished 钩子：保存用户明确表达的长期偏好和纠正。
@MainActor
public struct MemoryTurnFinishedHook {
    public init() {}

    public func execute(
        kernel: LumiKernel,
        conversationID: UUID,
        reason: LumiTurnEndReason
    ) async {
        let config = MemoryPlugin.config
        guard config.autoSave,
              reason == .completed,
              let messages = kernel.messageManager?.messages(for: conversationID)
        else { return }

        let candidates = MemoryCandidateExtractor.extract(
            from: messages,
            projectPath: kernel.project?.currentProject?.path
        )
        for candidate in candidates {
            do {
                _ = try await MemoryStorageService.shared.upsertMemory(
                    id: candidate.id,
                    type: candidate.type,
                    name: candidate.name,
                    description: candidate.description,
                    content: candidate.content,
                    scope: candidate.scope
                )
            } catch {
                // Memory is supplementary; persistence failure must not fail a completed turn.
                if MemoryPlugin.verbose {
                    MemoryPlugin.logger.error("🧠 自动保存记忆失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
