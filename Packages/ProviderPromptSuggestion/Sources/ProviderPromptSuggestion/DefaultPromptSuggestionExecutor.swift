import Foundation
import KitLocalization
import KernelCore
import ProviderActivityBar
import ProviderMessageSender
import ProviderPluginControl
import ProviderPluginManaging
import ProviderRailView
import ProviderToast

/// Default coordinator for prompt suggestion actions.
@MainActor
public final class DefaultPromptSuggestionExecutor: PromptSuggestionExecuting {
    private weak var kernel: KernelCoreContainer?

    public init(kernel: KernelCoreContainer? = nil) {
        self.kernel = kernel
    }

    public func attach(kernel: KernelCoreContainer) {
        self.kernel = kernel
    }

    public func execute(
        _ suggestion: PromptSuggestion,
        pickProjectFolder: (() -> Void)? = nil
    ) async {
        guard let kernel else { return }

        switch suggestion.action {
        case .pickProjectFolder:
            pickProjectFolder?()
            return
        case .openSettingsTab:
            NotificationCenter.default.post(
                name: Notification.Name("lumi.openSettings"),
                object: nil
            )
            return
        case nil, .activatePluginEntry, .activateRailTab:
            break
        }

        if suggestion.requiresEnable, let pluginID = suggestion.pluginID {
            guard let control = kernel.resolveProvider((any PluginControlling).self),
                  await control.enablePlugin(id: pluginID) else {
                return
            }

            let name = kernel
                .resolveProvider((any PluginManaging).self)?
                .plugin(id: pluginID)?
                .metadata.name ?? pluginID
            let enabledTitle = LumiLocalization.string(
                "Plugin Enabled",
                bundle: .module
            )
            let enabledDetail = LumiLocalization.string(
                "is now enabled.",
                bundle: .module
            )
            kernel.resolveProvider((any ToastProviding).self)?.show(
                enabledTitle,
                detail: "\(name) \(enabledDetail)",
                style: .success
            )
        }

        switch suggestion.action {
        case let .activatePluginEntry(activityBarItemID, railTabID, railGroupID):
            kernel.resolveProvider((any ActivityBarProviding).self)?
                .activateItem(id: activityBarItemID)
            kernel.resolveProvider((any RailViewProviding).self)?.activateGroup(id: railGroupID)
            kernel.resolveProvider((any RailViewProviding).self)?.activateTab(id: railTabID)
        case let .activateRailTab(railTabID, railGroupID):
            // Rail groups are selected by the plugin's ActivityBar callback.
            // The suggestion only needs to select the requested tab after that.
            kernel.resolveProvider((any RailViewProviding).self)?.activateGroup(id: railGroupID)
            kernel.resolveProvider((any RailViewProviding).self)?.activateTab(id: railTabID)
        default:
            break
        }

        try? await kernel
            .resolveProvider((any MessageSendingProviding).self)?
            .sendMessage(suggestion.prompt, conversationID: nil)
    }
}
