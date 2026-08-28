import Combine
import Foundation
import KernelCore
import ProviderConversation
import ProviderProject

/// V2 runtime state coordination.
///
/// Provider/model selection and conversation behaviour are now owned by their
/// dedicated V2 plugins. This plugin retains the legacy StateMonitor rules that
/// have no other owner: selecting a project-bound conversation follows its
/// project, and independently changing projects clears an incompatible selection.
@MainActor
public final class StateMonitorPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.state-monitor"
    public let order = 75
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.state-monitor",
        name: "State Monitor",
        description: "Keeps selected conversations and projects in sync.",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var projectChangeCancellable: AnyCancellable?
    private var previousProjectPath: String?
    private weak var conversations: (any ConversationManaging)?
    private weak var project: (any ProjectProviding)?

    public init() {}

    public func onReady(kernel: KernelCoreContainer) throws {
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let project = kernel.resolveProvider((any ProjectProviding).self) else {
            return
        }
        self.conversations = conversations
        self.project = project
        previousProjectPath = Self.normalized(project.currentProject?.path)

        selectedConversationObserver = conversations.addSelectedConversationObserver { [weak self] id in
            self?.followProjectBoundConversation(id)
        }
        projectChangeCancellable = project.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // ObservableObject publishes before mutation; defer one run-loop turn
                // so `currentProject` contains the new value before reconciliation.
                DispatchQueue.main.async { self?.reconcileProjectChange() }
            }

        followProjectBoundConversation(conversations.selectedConversationID)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        projectChangeCancellable?.cancel()
        projectChangeCancellable = nil
        previousProjectPath = nil
        conversations = nil
        project = nil
    }

    private func followProjectBoundConversation(_ conversationID: UUID?) {
        guard let conversationID,
              let conversations,
              let project else { return }
        Task { [weak self, conversations, project] in
            guard let summary = await conversations.fetchConversation(id: conversationID),
                  let path = Self.normalized(summary.projectPath),
                  Self.normalized(project.currentProject?.path) != path
            else { return }
            try? await project.openProject(at: path)
            self?.previousProjectPath = path
        }
    }

    private func reconcileProjectChange() {
        guard let conversations, let project else { return }
        let newPath = Self.normalized(project.currentProject?.path)
        guard newPath != previousProjectPath else { return }
        previousProjectPath = newPath
        guard let selectedID = conversations.selectedConversationID else { return }

        Task { [weak conversations, weak project] in
            guard let conversations,
                  let project,
                  conversations.selectedConversationID == selectedID,
                  let summary = await conversations.fetchConversation(id: selectedID),
                  Self.normalized(summary.projectPath) != Self.normalized(project.currentProject?.path)
            else { return }
            conversations.deselectConversation()
        }
    }

    static func normalized(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
