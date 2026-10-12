import Combine
import Foundation

// MARK: - 调用层级能力（契约 V2，§8）

/// 调用层级数据面：在指定位置准备调用层级会话，并请求 caller/callee。
///
/// 节点 `id` 由宿主签发，可安全回传给 `fetchIncomingCalls`/`fetchOutgoingCalls`。
@MainActor
public protocol EditorCallHierarchyProviding: AnyObject {
    /// 当前调用层级状态（CurrentValue 语义，可随时读取重放）。
    var hierarchy: EditorCallHierarchyState { get }

    /// 状态变更流；不以 failure 结束，新订阅者先收到当前值（§8.8）。
    var statePublisher: AnyPublisher<EditorCallHierarchyState, Never> { get }

    /// 在指定位置准备调用层级（root = 光标处符号）。
    func prepare(uri: URL, position: EditorPosition)

    /// 请求某节点的调用者（incoming calls）。
    func fetchIncomingCalls(node: EditorCallHierarchyNode)

    /// 请求某节点的被调用者（outgoing calls）。
    func fetchOutgoingCalls(node: EditorCallHierarchyNode)

    /// 清空调用层级会话。
    func clear()
}
