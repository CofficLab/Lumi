import Foundation

// MARK: - Typed kernel event bus + legacy Notification bridge

/// 内核级事件协议。插件事件应实现 `Sendable`，避免跨任务共享可变状态。
public protocol KernelEvent: Sendable {}

/// Notification carries legacy `Any` payloads. The bridge consumes it synchronously on
/// NotificationCenter's main queue and never lets the value escape that callback.
private struct MainQueueNotification: @unchecked Sendable {
    let value: Notification
}

/// 事件订阅令牌：取消后不再接收该订阅的事件。
@MainActor
public final class KernelEventSubscription {
    private let id: UUID
    private var isActive = true
    private let onCancel: () -> Void

    init(id: UUID, onCancel: @escaping () -> Void) {
        self.id = id
        self.onCancel = onCancel
    }

    public var isCancelled: Bool { !isActive }

    public func cancel() {
        guard isActive else { return }
        isActive = false
        onCancel()
    }
}

/// 内核类型化事件总线。
///
/// 插件通过 `subscribe` 接收类型化事件；通过 `publish` 发布事件。
/// `bridgeLegacyNotification` 把旧 `NotificationCenter` 通知转换为类型化事件，
/// 让旧通知消费者迁移到类型安全 API 的同时保留旧通知的发送方兼容。
@MainActor
public final class KernelCoreEventBus {
    private var subscribers: [ObjectIdentifier: [UUID: (any KernelEvent) -> Void]] = [:]
    private let notificationCenter: NotificationCenter

    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    /// 订阅指定类型的事件。返回订阅令牌，可在 `deinit`/卸载时取消。
    @discardableResult
    public func subscribe<T: KernelEvent>(
        _ type: T.Type,
        handler: @escaping (T) -> Void
    ) -> KernelEventSubscription {
        let key = ObjectIdentifier(T.self)
        let id = UUID()
        let box: (any KernelEvent) -> Void = { event in
            guard let typed = event as? T else { return }
            handler(typed)
        }
        subscribers[key, default: [:]][id] = box
        return KernelEventSubscription(id: id) { [weak self] in
            self?.subscribers[key]?.removeValue(forKey: id)
        }
    }

    /// 发布类型化事件，分发给全部匹配订阅者。
    public func publish(_ event: any KernelEvent) {
        let key = ObjectIdentifier(type(of: event))
        guard let handlers = subscribers[key]?.values else { return }
        for box in handlers {
            box(event)
        }
    }

    /// 旧 Notification → 类型化事件桥。
    ///
    /// - Parameters:
    ///   - name: 要监听的旧通知名。
    ///   - parse: 把 `Notification` 解析为事件；返回 `nil` 表示忽略该通知。
    /// - Returns: 桥接订阅令牌；取消后停止监听旧通知。
    @discardableResult
    public func bridgeLegacyNotification(
        name: Notification.Name,
        parse: @escaping @MainActor @Sendable (Notification) -> (any KernelEvent)?
    ) -> KernelEventSubscription {
        let observer = notificationCenter.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let notification = MainQueueNotification(value: notification)
            // 通知在 .main queue 投递，等价于 MainActor 上下文。
            MainActor.assumeIsolated {
                guard let event = parse(notification.value) else { return }
                self?.publish(event)
            }
        }
        return KernelEventSubscription(id: UUID()) { [weak self] in
            self?.notificationCenter.removeObserver(observer)
        }
    }

    /// 发布一个事件，同时以旧 `Notification` 形式广播（供尚未迁移的消费者兼容）。
    public func publishAsLegacy(_ event: any KernelEvent, notificationName: Notification.Name, userInfo: [AnyHashable: Any]? = nil) {
        publish(event)
        notificationCenter.post(name: notificationName, object: nil, userInfo: userInfo)
    }

    /// 当前订阅总数（诊断用）。
    public var activeSubscriptionCount: Int {
        subscribers.values.reduce(0) { $0 + $1.count }
    }
}
