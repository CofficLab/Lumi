import Foundation
import KernelCore
import ProviderActivityBar
import ProviderMessageSender
import ProviderPluginControl
import ProviderPluginManaging
import ProviderRailView
import ProviderToast
import ProviderWorkspace

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
        case nil, .activatePluginEntry, .activateViewContainer, .activateRailTab:
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
            kernel.resolveProvider((any ToastProviding).self)?.show(
                "Plugin Enabled",
                detail: "\(name) is now enabled.",
                style: .success
            )
        }

        switch suggestion.action {
        case let .activatePluginEntry(activityBarItemID, railTabID, containerID):
            kernel.resolveProvider((any ActivityBarProviding).self)?
                .activateItem(id: activityBarItemID)
            kernel.resolveProvider((any RailViewProviding).self)?.activateGroup(id: containerID)
            kernel.resolveProvider((any RailViewProviding).self)?.activateTab(id: railTabID)
            if let workspace = kernel.resolveProvider((any WorkspaceProviding).self) {
                workspace.activateContainer(id: containerID)
                workspace.presentRailTab(id: railTabID, for: containerID)
            }
        case let .activateViewContainer(id):
            kernel.resolveProvider((any WorkspaceProviding).self)?.activateContainer(id: id)
        case let .activateRailTab(railTabID, containerID):
            kernel.resolveProvider((any RailViewProviding).self)?.activateGroup(id: containerID)
            kernel.resolveProvider((any RailViewProviding).self)?.activateTab(id: railTabID)
            if let workspace = kernel.resolveProvider((any WorkspaceProviding).self) {
                workspace.activateContainer(id: containerID)
                workspace.presentRailTab(id: railTabID, for: containerID)
            }
        default:
            break
        }

        try? await kernel
            .resolveProvider((any MessageSendingProviding).self)?
            .sendMessage(suggestion.prompt, conversationID: nil)
    }
}
