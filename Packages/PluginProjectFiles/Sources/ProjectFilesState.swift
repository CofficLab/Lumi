import Combine
import Foundation
import KernelLumi

/// 已打开文件标签的合并视图模型。
///
/// Phase 3 迁移（重构方案 §17.2 / §20）：标签列表的唯一事实源是
/// `kernel.editorV2.sessions`（Editor Session 状态），不再读
/// `ProjectProviding.openFileURLs/currentFileURL`。
struct ProjectFilesState {
    /// 标签展示项。
    struct TabItem: Equatable, Identifiable {
        let id: EditorSessionID
        let uri: URL
        let isDirty: Bool
    }

    /// 从 workbench 状态提取可展示的标签（有 URI 的 session），保持标签顺序。
    static func tabItems(from state: EditorWorkbenchState) -> [TabItem] {
        state.allTabs.compactMap { tab in
            guard let uri = tab.uri else { return nil }
            return TabItem(id: tab.id, uri: uri.standardizedFileURL, isDirty: tab.isDirty)
        }
    }

    /// 当前激活文件的标准化 URL。
    static func activeFileURL(from state: EditorWorkbenchState) -> URL? {
        state.activeTab?.uri?.standardizedFileURL
    }
}

/// 订阅编辑器 Session 状态（CurrentValue 语义：init 即收到当前快照）。
@MainActor
final class ProjectFilesEditorObserver: ObservableObject {
    @Published private(set) var workbenchState = EditorWorkbenchState(groups: [], activeGroupID: nil)

    private var cancellable: AnyCancellable?

    init(kernel: KernelLumi) {
        // editorV2 由 EditorHostPlugin 注册；Host 未就绪（如精简宿主/测试）
        // 时保持空状态，视图显示空态而不是依赖 Project 侧数据。
        guard let sessions = kernel.editorV2?.sessions else { return }
        workbenchState = sessions.state
        cancellable = sessions.statePublisher.sink { [weak self] state in
            self?.workbenchState = state
        }
    }
}
