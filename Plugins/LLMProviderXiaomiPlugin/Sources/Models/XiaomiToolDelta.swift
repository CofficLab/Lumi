import Foundation

/// 单个 tool-call 在流式事件中的增量。
///
/// `id` 和 `name` 仅在新工具出现时携带，后续 chunk 只填充 `arguments`。
struct XiaomiToolDelta: Sendable {
    let id: String?
    let name: String?
    let arguments: String
}
