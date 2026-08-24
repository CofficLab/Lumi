import Foundation
import KernelLumi
import ProviderConversationInput

/// Runtime bridge for accessing the view model from plugin contribution closures.
///
/// The `viewContainers(kernel:)` closure captures no kernel context, so the view
/// model is exposed via this static bridge (same pattern as `ProjectsPlugin`).
@MainActor
public enum RuntimeBridge {
    public static var viewModel: StoryWriterViewModel?
    public static var kernel: KernelLumi?
    public static var conversationInput: (any ProviderConversationInput.ConversationInputProviding)?
}
