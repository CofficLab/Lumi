import Combine
import Foundation

/// Session、标签与 Editor Group 能力（契约 V2，见重构方案 §8.3）。
@MainActor
public protocol EditorSessionProviding: AnyObject {
    /// 工作台（多 Group）状态快照。
    var state: EditorWorkbenchState { get }

    /// 工作台状态流（CurrentValue 语义）。
    var statePublisher: AnyPublisher<EditorWorkbenchState, Never> { get }

    /// 激活某个 Session（切换标签）。
    func activate(sessionID: EditorSessionID)

    /// 按 `policy` 处理未保存修改并关闭 Session。
    func close(sessionID: EditorSessionID, policy: EditorClosePolicy) async throws

    /// 关闭除指定 Session 外的全部 Session。
    func closeOthers(keeping sessionID: EditorSessionID) async throws

    /// 关闭指定 Session 左侧的全部 Session。
    func closeToLeft(of sessionID: EditorSessionID) async throws

    /// 关闭指定 Session 右侧的全部 Session。
    func closeToRight(of sessionID: EditorSessionID) async throws

    /// 设置/取消标签置顶。
    func setPinned(_ pinned: Bool, sessionID: EditorSessionID)

    /// 组内重排：把 Session 移动到 `before` 之前（nil 为末尾）。
    func move(sessionID: EditorSessionID, before: EditorSessionID?, in groupID: EditorGroupID)

    /// 按方向分栏，返回新 Group。
    func split(sessionID: EditorSessionID, direction: EditorSplitDirection) -> EditorGroupID

    /// 把 Session 移动到另一 Group。
    func move(sessionID: EditorSessionID, to groupID: EditorGroupID)

    /// 导航历史后退。
    func navigateBack()

    /// 导航历史前进。
    func navigateForward()
}
