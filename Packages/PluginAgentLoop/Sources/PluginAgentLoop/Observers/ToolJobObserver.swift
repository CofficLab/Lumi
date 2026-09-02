import Foundation
import ProviderToolManager

/// Forwards tool-job lifecycle events to the AgentLoop manager.
@MainActor
final class ToolJobObserver {
    private var handle: (any ToolJobObserverHandle)?

    init(toolManager: any ToolManagerProviding, onEvent: @escaping (ToolJobEvent) -> Void) {
        handle = toolManager.addToolJobObserver { event in
            onEvent(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
