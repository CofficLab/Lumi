import Foundation

///「待取消」的会话 ID
@MainActor
final class TaskCancellationVM: ObservableObject {
    @Published private(set) var conversationIdToCancel: UUID?

    func requestCancel(conversationId: UUID) {
        conversationIdToCancel = conversationId
    }

    func consumeRequest() {
        conversationIdToCancel = nil
    }
}
