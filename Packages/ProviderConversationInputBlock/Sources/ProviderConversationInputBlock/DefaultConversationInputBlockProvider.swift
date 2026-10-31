import Foundation

/// 内存实现：生产方提交的块广播给消费方（当前只有输入插件）。
///
/// 第一个观察者注册前提交的块会暂存在缓冲区，并在注册时补投：插件启动顺序
/// 不确定，输入插件可能晚于一次右键发送才装配好，没有缓冲就会静默丢内容。
@MainActor
public final class DefaultConversationInputBlockProvider: ConversationInputBlockProviding {
    private var observers: [WeakBlockObserver] = []
    private var bufferedBlocks: [ConversationInputBlock] = []

    public init() {}

    public func submit(_ block: ConversationInputBlock) {
        guard !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !block.title.isEmpty else {
            return
        }

        observers.removeAll { $0.observer == nil }
        guard !observers.isEmpty else {
            // 还没有消费者，先缓冲，避免插件启动顺序导致内容丢失。
            bufferedBlocks.append(block)
            return
        }
        notify(.blockSubmitted(block))
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (ConversationInputBlockProvidingEvent) -> Void
    ) -> any ConversationInputBlockObserverHandle {
        let observer = BlockObserver(owner: self, callback: callback)
        observers.append(WeakBlockObserver(observer))

        if !bufferedBlocks.isEmpty {
            let pending = bufferedBlocks
            bufferedBlocks.removeAll()
            for block in pending {
                observer.invoke(.blockSubmitted(block))
            }
        }
        return observer
    }

    fileprivate func remove(_ observer: BlockObserver) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: ConversationInputBlockProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        for weak in observers {
            weak.observer?.invoke(event)
        }
    }
}

// MARK: - Block Observer Handle

@MainActor
private final class BlockObserver: ConversationInputBlockObserverHandle {
    private weak var owner: DefaultConversationInputBlockProvider?
    private let callback: (ConversationInputBlockProvidingEvent) -> Void
    private var isCancelled = false

    init(
        owner: DefaultConversationInputBlockProvider,
        callback: @escaping (ConversationInputBlockProvidingEvent) -> Void
    ) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.remove(self)
    }

    fileprivate func invoke(_ event: ConversationInputBlockProvidingEvent) {
        guard !isCancelled else { return }
        callback(event)
    }
}

/// 弱引用包装，令牌释放后自动失效。
@MainActor
private final class WeakBlockObserver {
    fileprivate weak var observer: BlockObserver?
    init(_ observer: BlockObserver) { self.observer = observer }
}