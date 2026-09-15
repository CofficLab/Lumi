import Foundation
import ProviderProjectRAG

/// 订阅 ProjectRAG 外部事件，收到后**直接**刷新 `ProjectRAGStatusViewModel`。
/// 在插件组装层创建并持有生命周期。
@MainActor
final class ProjectRAGStatusObserver {
    private let capability: ProjectRAGStatusCapability
    private let viewModel: ProjectRAGStatusViewModel
    private var handle: (any ProjectRAGObserverHandle)?

    init(capability: ProjectRAGStatusCapability, viewModel: ProjectRAGStatusViewModel) {
        self.capability = capability
        self.viewModel = viewModel
        handle = capability.addObserver { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.viewModel.loadStatus()
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
