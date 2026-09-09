import Foundation
import os
import KitSuperLog

@MainActor
public final class DefaultConversationInputProvider: ConversationInputProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-conversation-input", category: "ConversationInput")
    nonisolated public static let emoji = "💬"
    nonisolated static let verbose = false

    public var text = "" {
        didSet {
            guard text != oldValue else { return }
            if Self.verbose {
                Self.logger.debug("\(self.t)text changed, length=\(self.text.count)")
            }
            notifyTextObservers()
        }
    }
    public var inputHeight: CGFloat = 40
    public var isInputFocused = false
    public var inputCursorPosition = 0
    public var errorMessage: String? {
        didSet {
            guard errorMessage != oldValue else { return }
            if let errorMessage {
                Self.logger.error("\(self.t)error set ➡️ \(errorMessage, privacy: .public)")
            }
            notify(.errorMessageChanged(errorMessage))
        }
    }
    public private(set) var isSending = false {
        didSet {
            guard isSending != oldValue else { return }
            Self.logger.info("\(self.t)isSending: \(oldValue) ➡️ \(self.isSending)")
        }
    }

    // MARK: - Text Observation

    private var textObservers: [WeakTextInputObserver] = []
    private var observers: [WeakObserver] = []

    @discardableResult
    public func addTextObserver(_ callback: @escaping (String) -> Void) -> any TextInputObserverHandle {
        let handle = TextInputObserverHandleImpl(owner: self, callback: callback)
        textObservers.append(WeakTextInputObserver(handle))
        if Self.verbose {
            Self.logger.debug("\(self.t)text observer added, total=\(self.textObservers.count)")
        }
        return handle
    }

    fileprivate func removeTextObserver(_ handle: TextInputObserverHandleImpl) {
        textObservers.removeAll { $0.handle === handle }
        if Self.verbose {
            Self.logger.debug("\(self.t)text observer removed, remaining=\(self.textObservers.count)")
        }
    }

    private func notifyTextObservers() {
        textObservers.removeAll { $0.handle == nil }
        let observers = textObservers
        let currentText = text
        for observer in observers {
            observer.handle?.invoke(currentText)
        }
    }

    @discardableResult
    public func addObserver(_ callback: @escaping (ConversationInputProvidingEvent) -> Void) -> any ConversationInputProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    fileprivate func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: ConversationInputProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        let activeObservers = observers
        for observer in activeObservers {
            observer.observer?.invoke(event)
        }
    }

    // MARK: -

    public init() {
        Self.logger.info("\(Self.onInit)initialized")
    }

    public func addToConversation(fileURLs: [URL]) {
        let paths = fileURLs.map(\.path).joined(separator: "\n")
        text += paths
    }

    public func clear() {
        text = ""
        errorMessage = nil
    }
}

// MARK: - Text Observer Handle

/// 文本观察者令牌：弱引用 owner，释放或 cancel 后自动停止接收。
@MainActor
private final class TextInputObserverHandleImpl: TextInputObserverHandle {
    private weak var owner: DefaultConversationInputProvider?
    private let callback: (String) -> Void
    private var isCancelled = false

    init(owner: DefaultConversationInputProvider, callback: @escaping (String) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeTextObserver(self)
    }

    fileprivate func invoke(_ text: String) {
        guard !isCancelled else { return }
        callback(text)
    }
}

/// 弱引用包装，令牌释放后自动失效。
@MainActor
private final class WeakTextInputObserver {
    fileprivate weak var handle: TextInputObserverHandleImpl?
    init(_ handle: TextInputObserverHandleImpl) { self.handle = handle }
}

@MainActor
private final class Observer: ConversationInputProvidingObserverHandle {
    private weak var owner: DefaultConversationInputProvider?
    private let callback: (ConversationInputProvidingEvent) -> Void
    private var isCancelled = false

    init(owner: DefaultConversationInputProvider, callback: @escaping (ConversationInputProvidingEvent) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.remove(self)
    }

    fileprivate func invoke(_ event: ConversationInputProvidingEvent) {
        guard !isCancelled else { return }
        callback(event)
    }
}

@MainActor
private final class WeakObserver {
    fileprivate weak var observer: Observer?
    init(_ observer: Observer) { self.observer = observer }
}
