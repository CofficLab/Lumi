import Combine
import Foundation
import ProviderProject

/// 文件树插件的项目状态。
///
/// 项目状态的权威来源是 `ProjectProviding`；本 ViewModel 只缓存插件视图
/// 需要的当前项目快照，不自行创建或维护项目数据。
@MainActor
final class ProjectFileTreeViewModel: ObservableObject {
    @Published private(set) var currentProject: ProjectInfo?

    var currentProjectPath: String {
        currentProject?.path ?? ""
    }

    func updateCurrentProject(_ project: ProjectInfo?) {
        guard currentProject != project else { return }
        currentProject = project
    }
}
