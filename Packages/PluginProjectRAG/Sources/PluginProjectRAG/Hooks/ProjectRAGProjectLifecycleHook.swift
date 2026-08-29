import Foundation
import ProjectRAGEngine
import ProviderProject

/// 监听当前项目变化，并为新项目安排后台增量索引。
///
/// 项目恢复可能晚于 ProjectRAG 插件的 `onBoot`，因此不能只在插件启动时
/// 读取一次 `currentProject`。
@MainActor
final class ProjectRAGProjectLifecycleHook {
    private let service: RAGService
    private var observer: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding, service: RAGService) {
        self.service = service
        observer = project.addObserver { [service] event in
            guard case let .currentProjectChanged(projectInfo) = event,
                  let path = projectInfo?.path,
                  !path.isEmpty else {
                return
            }

            Task {
                do {
                    try await service.initialize()
                    await service.ensureIndexedBackground(projectPath: path)
                } catch {
                    // 插件启动或服务重建期间失败时，下一次项目事件或查询会重试。
                }
            }
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }
}
