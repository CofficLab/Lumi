import Foundation
import ProviderDocsView

/// 通用设置页外部事件 → ViewModel 的桥梁。
///
/// 在插件组装层创建，订阅说明书条目变化事件并直接刷新
/// `GeneralSettingsViewModel.manuals`；不向外传回调。
@MainActor
final class GeneralSettingsObserver {
    private let capability: any GeneralSettingsCapability
    private let viewModel: GeneralSettingsViewModel
    private var docsObserverHandle: (any DocsViewObserverHandle)?

    init(
        capability: any GeneralSettingsCapability,
        viewModel: GeneralSettingsViewModel
    ) {
        self.capability = capability
        self.viewModel = viewModel
        viewModel.refreshManuals()
        docsObserverHandle = capability.addDocsViewObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .manualEntriesChanged, .aboutEntriesChanged:
                self.viewModel.refreshManuals()
            }
        }
    }

    func cancel() {
        docsObserverHandle?.cancel()
        docsObserverHandle = nil
    }
}
