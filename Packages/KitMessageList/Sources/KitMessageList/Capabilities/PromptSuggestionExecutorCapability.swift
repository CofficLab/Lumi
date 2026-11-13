import ProviderPromptSuggestion

/// 提示建议执行所需的最小能力。
@MainActor
public protocol MessageListPromptSuggestionExecutorCapability: AnyObject {
    func execute(_ suggestion: PromptSuggestion, pickProjectFolder: (() -> Void)?) async
}

@MainActor
public final class MessageListPromptSuggestionExecutorCapabilityAdapter: MessageListPromptSuggestionExecutorCapability {
    private let executor: any PromptSuggestionExecuting
    public init(executor: any PromptSuggestionExecuting) { self.executor = executor }
    public func execute(_ suggestion: PromptSuggestion, pickProjectFolder: (() -> Void)?) async {
        await executor.execute(suggestion, pickProjectFolder: pickProjectFolder)
    }
}