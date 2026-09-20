import Combine
import Foundation

// MARK: - 引用能力（契约 V2，§8）

/// 引用/定义结果数据面。
@MainActor
public protocol EditorReferencesProviding: AnyObject {
    /// 当前引用面板状态（CurrentValue 语义，可随时读取重放）。
    var references: EditorReferencesState { get }

    /// 引用状态变更流；不以 failure 结束，新订阅者先收到当前值（§8.8）。
    var statePublisher: AnyPublisher<EditorReferencesState, Never> { get }
}
