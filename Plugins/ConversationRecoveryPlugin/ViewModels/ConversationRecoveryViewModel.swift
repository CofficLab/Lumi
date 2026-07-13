import Foundation
import LumiChatKit
import LumiCoreKit
import os

/// 对话恢复视图模型
///
/// 从 ConversationRecoveryStateMonitor 获取中断状态，
/// 通过 ConversationRecoveryService 执行恢复/忽略。
@MainActor
public final class ConversationRecoveryViewModel: ObservableObject {
    @Published public var interruption: LumiConversationInterruption?

    private let monitor = ConversationRecoveryStateMonitor.shared
    private let service = ConversationRecoveryService.shared
    private var notificationObserver: NSObjectProtocol?

    public init() {}

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// 刷新当前会话的中断状态
    public func refresh(conversationID: UUID?) {
        guard let conversationID else {
            interruption = nil
            return
        }

        interruption = monitor.getInterruption(for: conversationID)

        if notificationObserver == nil {
            notificationObserver = NotificationCenter.default.addObserver(
                forName: .lumiMessageSaved,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let convID = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID,
                       convID == conversationID {
                        self.interruption = self.monitor.getInterruption(for: conversationID)
                    }
                }
            }
        }
    }

    /// 恢复对话
    public func recover() async {
        guard let interruption else { return }
        await service.recover(interruption: interruption)
        self.interruption = nil
    }

    /// 忽略中断
    public func dismiss() {
        guard let interruption else { return }
        service.dismiss(interruption: interruption)
        self.interruption = nil
    }
}
