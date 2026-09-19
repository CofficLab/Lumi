import Foundation
import ProviderProject

/// 把当前项目的变化转发给原型设计器运行时。
@MainActor
final class PrototypeDesignerProjectObserver {
    private var handle: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding, onChange: @escaping (String?) -> Void) {
        handle = project.addObserver { [weak project] event in
            guard case .currentProjectChanged = event else { return }
            onChange(project?.currentProject?.path)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
