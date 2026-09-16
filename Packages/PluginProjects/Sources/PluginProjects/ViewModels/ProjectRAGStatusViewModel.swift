import Foundation
import ProviderProjectRAG

/// 项目详情中 RAG 索引状态的唯一数据来源。
///
/// Provider 通过 `ProjectRAGStatusCapability` 解析；索引事件由
/// `ProjectRAGStatusObserver` 写入，View 只读取本 ViewModel。
@MainActor
final class ProjectRAGStatusViewModel: ObservableObject {
    enum LoadState {
        case loading
        case unavailable
        case notIndexed
        case indexed(ProjectRAGIndexStatus)
        case failed
    }

    @Published private(set) var state: LoadState = .loading

    private let projectPath: String
    private let capability: ProjectRAGStatusCapability

    init(projectPath: String, capability: ProjectRAGStatusCapability) {
        self.projectPath = projectPath
        self.capability = capability
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    /// 加载/刷新 RAG 索引状态。
    func loadStatus() async {
        state = .loading
        guard let provider = capability.provider else {
            state = .unavailable
            return
        }

        do {
            state = try await provider.indexStatus(projectPath: projectPath).map(LoadState.indexed) ?? .notIndexed
        } catch {
            state = .failed
        }
    }
}
