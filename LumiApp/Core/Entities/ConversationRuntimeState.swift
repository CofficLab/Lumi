import Foundation

/// 会话运行态（供 `ConversationRuntimeStore` / UI 徽标使用）。
enum ConversationRuntimeState: String {
    case idle
    case generating
    case waitingPermission
    case error
}
