import Foundation

/// 持有 `MessageStore` 的进程内单例。
///
/// 不加 actor 隔离:消息读取可在后台线程执行,故 `store` 的读写通过内部锁保护,
/// 保证主线程(onReady 赋值)与后台读取线程之间的并发安全。
final class MessageStoreRuntimeBridge: @unchecked Sendable {
    static let shared = MessageStoreRuntimeBridge()

    private let lock = NSLock()
    private var _store: MessageStore?

    var store: MessageStore? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _store
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _store = newValue
        }
    }

    private init() {}
}
