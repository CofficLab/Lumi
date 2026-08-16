import Combine
import Foundation
import KernelLumi

/// Workspace Search 面板视图模型：订阅 KernelLumi V2 搜索状态并暴露操作。
///
/// 查询文本、文件折叠与选中命中属于面板局部 UI 状态，由插件自持
/// （V2 契约的 `EditorWorkspaceSearchState` 不再承载这些字段）。
@MainActor
public final class BottomWorkspaceSearchViewModel: ObservableObject {
    @Published public private(set) var state: EditorWorkspaceSearchState = .empty

    /// 搜索框文本。
    @Published public var query: String = ""

    /// 折叠的文件分组路径（插件局部状态）。
    @Published public private(set) var collapsedFilePaths: Set<String> = []

    /// 当前选中的命中（插件局部状态）。
    @Published public private(set) var selectedMatchID: String?

    private let editor: any EditorProvidingV2
    private var cancellables: Set<AnyCancellable> = []

    public init(editor: any EditorProvidingV2) {
        self.editor = editor
        state = editor.workspaceSearch.search
        editor.workspaceSearch.statePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
    }

    /// 执行工作区搜索（宿主自行决定去抖/取消策略）。
    public func performSearch() {
        editor.workspaceSearch.performSearch(query)
    }

    /// 打开一条命中并记录选中。
    public func openMatch(_ match: EditorSearchMatch) {
        selectedMatchID = match.id
        editor.workspaceSearch.openMatch(match)
    }

    /// 把全部搜索结果作为文档在编辑器中打开。
    public func openResultsInEditor() {
        editor.workspaceSearch.openResultsInEditor()
    }

    /// 切换某文件分组的折叠状态。
    public func toggleFileCollapse(path: String) {
        if collapsedFilePaths.contains(path) {
            collapsedFilePaths.remove(path)
        } else {
            collapsedFilePaths.insert(path)
        }
    }
}
