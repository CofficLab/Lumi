import Combine
import Foundation

// MARK: - 诊断能力（契约 V2，§8）

/// 诊断数据面：快照 + 变更流。
///
/// 与 `EditorFeature.diagnostics` 的可用性查询（`extensions.availability`）互补：
/// 本协议提供**数据**，availability 提供**能力判定**。
@MainActor
public protocol EditorDiagnosticsProviding: AnyObject {
    /// 当前诊断快照（CurrentValue 语义，可随时读取重放）。
    var snapshot: EditorDiagnosticsSnapshot { get }

    /// 诊断变更流；不以 failure 结束，新订阅者先收到当前快照（§8.8）。
    var statePublisher: AnyPublisher<EditorDiagnosticsSnapshot, Never> { get }
}
