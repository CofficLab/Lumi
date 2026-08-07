import Combine
import Foundation

/// SwiftUI 友好的 `MessageManaging` 窄播包装器。
///
/// 与 `ObservableConversationsBox`、`ObservableWorkspaceBox` 等同理：SwiftUI 的
/// `@ObservedObject` 不支持 `any MessageManaging` 这样的存在类型，需要用具体类
/// 包装，把 service 的 `objectWillChange` 桥接到自己的 publisher 上。
///
/// **为何需要独立订阅**：消息计数 / 流式速度等工具栏只关心某个对话的消息列表，
/// 同时依赖 `conversations.selectedConversationID`（决定看哪个对话）和
/// `messageManager`（决定消息内容）。若经 kernel 的全局 objectWillChange 转发，
/// project/settings 等无关服务变更都会让这些视图重求值。用本包装器让消费视图
/// 精确订阅 messageManager service，绕开全局广播。
///
/// 用法：
/// ```swift
/// @StateObject private var box = ObservableMessageManagerBox()
/// // 在 task 里绑定：
/// box.bind(kernel.messageManager)
/// // 视图里读：box.service?.messages(for: conversationID)
/// ```
@MainActor
public final class ObservableMessageManagerBox: ObservableObject {
    /// 被包装的服务实例。绑定前为 nil。
    public private(set) var service: (any MessageManaging)?

    private var cancellable: AnyCancellable?

    public init() {}

    /// 绑定（或重新绑定）一个 `MessageManaging` 服务。
    /// 重复绑定同一实例为 no-op；绑定不同实例会切换订阅。
    public func bind(_ service: (any MessageManaging)?) {
        // 已绑定同一实例：跳过，避免重复订阅。
        if service != nil && service === self.service { return }
        self.service = service
        cancellable = nil
        guard let service else { return }
        cancellable = service.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
}
