import Foundation

/// 负责收集“创建新会话”所需的数据并发布创建请求。
@MainActor
final class ConversationCreationVM: ObservableObject {
    @Published private(set) var pendingRequest: UUID?
    private var requestContinuations: [UUID: CheckedContinuation<Void, Never>] = [:]

    func createNewConversation() async {
        let request = UUID()
        pendingRequest = request

        await withCheckedContinuation { continuation in
            requestContinuations[request] = continuation
        }
    }

    func consumePendingRequest(id: UUID) -> UUID? {
        guard let request = pendingRequest, request == id else { return nil }
        pendingRequest = nil
        return request
    }

    func completeRequest(id: UUID) {
        guard let continuation = requestContinuations.removeValue(forKey: id) else { return }
        continuation.resume()
    }
}
