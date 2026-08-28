import Combine
import Foundation

// MARK: - 工作区搜索能力（契约 V2，§8）

/// 工作区搜索数据面：发起搜索、消费结果、打开命中。
@MainActor
public protocol EditorWorkspaceSearchProviding: AnyObject {
    /// 当前搜索状态（CurrentValue 语义，可随时读取重放）。
    var search: EditorWorkspaceSearchState { get }

    /// 搜索状态变更流；不以 failure 结束，新订阅者先收到当前值（§8.8）。
    var statePublisher: AnyPublisher<EditorWorkspaceSearchState, Never> { get }

    /// 执行工作区搜索（宿主自行决定去抖/取消策略）。
    func performSearch(_ query: String)

    /// 在编辑器中打开单条命中。
    func openMatch(_ match: EditorSearchMatch)

    /// 把全部搜索结果作为文档在编辑器中打开。
    func openResultsInEditor()
}
