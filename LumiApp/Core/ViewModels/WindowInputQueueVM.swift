import Foundation
import MagicKit

/// 负责收集用户输入并发布入队请求
@MainActor
final class WindowInputQueueVM: ObservableObject, SuperLog {
    nonisolated static var emoji: String { "🔄" }
    nonisolated static var verbose: Bool { false }

    @Published private(set) var pendingRequest: InputEnqueueRequest?
    
    /// 输入入队请求版本号，每次发布新请求时递增，用于外部监听
    @Published private(set) var queueVersion: Int = 0

    struct InputEnqueueRequest: Identifiable, Equatable {
        let id: UUID
        let text: String
        let images: [ImageAttachment]
    }

    /// 发布输入入队请求
    func enqueueText(_ text: String, images: [ImageAttachment] = []) {
        if Self.verbose {
            AppLogger.core.info("\(self.t)用户输入入队: \(text.max(50))")
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty else {
            AppLogger.core.info("\(self.t) 用户提供的消息文字和图片都是空，什么都不做")
            return
        }
        pendingRequest = InputEnqueueRequest(
            id: UUID(),
            text: trimmed,
            images: images
        )
        queueVersion += 1
        NotificationCenter.postUserDidSendMessage()
    }

    func consumePendingRequest(id: UUID) -> InputEnqueueRequest? {
        guard let request = pendingRequest, request.id == id else { return nil }
        pendingRequest = nil
        return request
    }
}
