import ProviderPromptSuggestion

/// 提示建议执行所需的最小能力。
@MainActor
protocol MessageListPromptSuggestionExecutorCapability: AnyObject {
    func execute(_ suggestion: PromptSuggestion, pickProjectFolder: (() -> Void)?) async
}

@MainActor
final class MessageListPromptSuggestionExecutorCapabilityAdapter: MessageListPromptSuggestionExecutorCapability {
    private let executor: any PromptSuggestionExecuting

    init(executor: any PromptSuggestionExecuting) {
        self.executor = executor
    }

    func execute(_ suggestion: PromptSuggestion, pickProjectFolder: (() -> Void)?) async {
        await executor.execute(suggestion, pickProjectFolder: pickProjectFolder)
    }
}
