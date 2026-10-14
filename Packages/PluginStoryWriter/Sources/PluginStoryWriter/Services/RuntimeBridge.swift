import Foundation
import ProviderConversationInput

@MainActor
enum RuntimeBridge {
    static var viewModel: StoryWriterViewModel?
    static var conversationInput: (any ConversationInputProviding)?
}

/// Shared storage location configured by the plugin entry point and consumed
/// by Story Writer tools.
enum StoryWriterStorage {
    static let pluginID = "StoryWriter"
    @MainActor static var v2Directory: URL?

    @MainActor static func configureV2(directory: URL?) {
        v2Directory = directory
    }
}
