import LumiKernel

/// Memory 插件 willSendToLLM 钩子：在请求前注入与当前问题相关的持久记忆。
@MainActor
public struct MemoryWillSendToLLMHook {
    public init() {}

    public func execute(
        kernel: LumiKernel,
        messages: [LumiChatMessage]
    ) async -> [LumiChatMessage] {
        await MemoryContextService.injectingRelevantMemories(
            into: messages,
            projectPath: kernel.project?.currentProject?.path
        )
    }
}
