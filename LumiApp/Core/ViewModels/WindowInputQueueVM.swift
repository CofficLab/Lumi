import Combine
import Foundation

///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有，通过 `.environmentObject()` 注入。nRootView 监听其 `queueVersion` 变化处理用户输入。
/// 负责收集用户输入并发布入队请求
///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有并通过 `.environmentObject()` 注入。
/// RootView 监听其 `queueVersion` 变化处理用户输入。
@MainActor
final class WindowInputQueueVM: ObservableObject, SuperLog {
    nonisolated static var emoji: String { "🔄" }
    nonisolated static var verbose: Bool { false }

    struct InputEnqueueRequest: Identifiable, Equatable {
        let id: UUID
        let text: String
        let images: [ImageAttachment]
    }

    @Published private(set) var pendingRequest: InputEnqueueRequest?

    /// 显式输入请求事件。RootView 直接消费事件，避免依赖 `@Published` 版本号再回读状态。
    let enqueueRequests = PassthroughSubject<InputEnqueueRequest, Never>()

    /// 直接输入处理回调，由 WindowContainer 绑定，避免依赖 SwiftUI `.onReceive` 事件桥。
    var onEnqueueRequest: ((InputEnqueueRequest) -> Void)?

    /// 输入入队请求版本号，每次发布新请求时递增，用于外部监听
    @Published private(set) var queueVersion: Int = 0

    /// 发布输入入队请求
    func enqueueText(_ text: String, images: [ImageAttachment] = []) {
        if Self.verbose {
            AppLogger.core.info("\(self.t)用户输入入队: \(text.max(count: 50))")
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty else {
            return
        }
        let request = InputEnqueueRequest(
            id: UUID(),
            text: trimmed,
            images: images
        )
        pendingRequest = request
        queueVersion += 1
        onEnqueueRequest?(request)
        enqueueRequests.send(request)
        NotificationCenter.postUserDidSendMessage()
    }

    func consumePendingRequest(id: UUID) -> InputEnqueueRequest? {
        guard let request = pendingRequest, request.id == id else { return nil }
        pendingRequest = nil
        return request
    }

    func clearForTeardown() {
        pendingRequest = nil
        onEnqueueRequest = nil
    }
}
