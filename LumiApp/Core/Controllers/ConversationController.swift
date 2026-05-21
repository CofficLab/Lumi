import Foundation
import MagicKit

/// 会话控制器
///
/// 每个窗口拥有独立的 ConversationController 实例，通过 WindowScope 直接访问窗口级 VM。
@MainActor
final class ConversationController: ObservableObject, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = false

    private let scope: WindowScope
    private let global: RootContainer

    init(scope: WindowScope, global: RootContainer) {
        self.scope = scope
        self.global = global
    }
}
