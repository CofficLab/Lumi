import ProviderConversationInput

@MainActor
enum RuntimeBridge {
    static var viewModel: StoryWriterViewModel?
    static var conversationInput: (any ConversationInputProviding)?
}
