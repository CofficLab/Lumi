import Foundation
import MagicKit

/// 负责收集用户输入并发布入队请求
@MainActor
final class InputQueueVM: ObservableObject, SuperLog {
    nonisolated static var emoji: String { "🔄" }
    nonisolated static var verbose: Bool { false }

    @Published private(set) var pendingRequest: InputEnqueueRequest?

    struct InputEnqueueRequest: Identifiable, Equatable {
        let id: UUID
        let text: String
        let images: [ImageAttachment]
    }

    /// 发布输入入队请求
    func enqueueText(_ text: String, images: [ImageAttachment] = []) {
        if Self.verbose {
            AppLogger.core.info("\(self.t) 用户输入入队: \(text.max(50))")
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty else { return }
        pendingRequest = InputEnqueueRequest(
            id: UUID(),
            text: trimmed,
            images: images
        )
    }

    func consumePendingRequest(id: UUID) -> InputEnqueueRequest? {
        guard let request = pendingRequest, request.id == id else { return nil }
        pendingRequest = nil
        return request
    }
}

