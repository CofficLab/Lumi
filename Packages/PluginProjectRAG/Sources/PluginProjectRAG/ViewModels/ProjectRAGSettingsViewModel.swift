import Foundation
import ProjectRAGEngine

/// Project RAG 设置页的数据源。
///
/// 自动注入开关落在 `RAGInjectionPolicy.autoInjectEnabledKey`（Hook 读取同一 key）；
/// 索引暂停以 `RAGService` 为唯一事实来源，写入后回读真实状态。
@MainActor
final class ProjectRAGSettingsViewModel: ObservableObject {
    @Published var autoInjectEnabled: Bool {
        didSet { defaults.set(autoInjectEnabled, forKey: RAGInjectionPolicy.autoInjectEnabledKey) }
    }
    @Published private(set) var indexingPaused = false

    private let service: RAGService
    private let defaults: UserDefaults

    init(service: RAGService, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        autoInjectEnabled = defaults.object(forKey: RAGInjectionPolicy.autoInjectEnabledKey) as? Bool ?? true
    }

    func load() async {
        indexingPaused = await service.isIndexingPaused()
    }

    func setIndexingPaused(_ paused: Bool) async {
        await service.setIndexingPaused(paused)
        indexingPaused = await service.isIndexingPaused()
    }
}