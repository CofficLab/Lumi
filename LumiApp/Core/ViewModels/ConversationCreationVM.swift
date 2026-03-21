import Foundation

/// 负责收集“创建新会话”所需的数据并发布创建请求。
@MainActor
final class ConversationCreationVM: ObservableObject {
    @Published private(set) var pendingRequest: ConversationCreationRequest?
    private var requestContinuations: [UUID: CheckedContinuation<Void, Never>] = [:]

    struct ConversationCreationRequest: Identifiable, Equatable {
        let id: UUID
    }

    func createNewConversation() async {
        let request = ConversationCreationRequest(
            id: UUID()
        )
        pendingRequest = request

        await withCheckedContinuation { continuation in
            requestContinuations[request.id] = continuation
        }
    }

    func consumePendingRequest(id: UUID) -> ConversationCreationRequest? {
        guard let request = pendingRequest, request.id == id else { return nil }
        pendingRequest = nil
        return request
    }

    func completeRequest(id: UUID) {
        guard let continuation = requestContinuations.removeValue(forKey: id) else { return }
        continuation.resume()
    }
}
