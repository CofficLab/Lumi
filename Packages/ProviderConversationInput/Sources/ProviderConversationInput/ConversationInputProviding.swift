import Combine
import Foundation
import SwiftUI

/// 输入文本变化观察者的注册令牌。
///
/// 调用 `ConversationInputProviding.addTextObserver(_:)` 后持有返回值
/// 即可持续接收输入文本变化通知；令牌释放（deinit）或显式调用 `cancel()` 时
/// 自动停止接收，无需手动反注册。
@MainActor
public protocol TextInputObserverHandle: AnyObject {
    /// 停止接收输入文本变化通知。重复调用无副作用。
    func cancel()
}

@MainActor
public protocol ConversationInputProviding: ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    var text: String { get set }
    var inputHeight: CGFloat { get set }
    var isInputFocused: Bool { get set }
    var inputCursorPosition: Int { get set }
    var errorMessage: String? { get set }
    var isSending: Bool { get }
    func addToConversation(fileURLs: [URL])
    func clear()

    // MARK: - Observation

    /// 注册一个观察者：当 `text` 变化时通过 callback 收到最新文本。
    ///
    /// 回调在主线程同步执行。仅当文本实际发生变化时触发。
    ///
    /// - Parameter callback: 文本变化时的通知回调，参数为最新文本。
    /// - Returns: 注销令牌；持有返回值即可持续接收，令牌释放或调用 `cancel()` 后自动停止。
    @discardableResult
    func addTextObserver(_ callback: @escaping (String) -> Void) -> any TextInputObserverHandle
}
