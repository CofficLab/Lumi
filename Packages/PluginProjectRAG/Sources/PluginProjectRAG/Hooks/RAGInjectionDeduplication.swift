import CryptoKit
import Foundation

/// 自动注入的去重窗口。
///
/// 只保留最近若干轮的固定大小摘要，避免把完整用户消息正文留在进程级集合里。
/// 容量用完后按记录顺序淘汰最旧的回合。
struct RAGInjectionDeduplication {
    struct Key: Hashable {
        let conversationID: UUID
        let userMessageCount: Int
        let contentDigest: String

        init(conversationID: UUID, userMessageCount: Int, content: String) {
            self.conversationID = conversationID
            self.userMessageCount = userMessageCount
            self.contentDigest = Self.digest(of: content)
        }

        private static func digest(of content: String) -> String {
            SHA256.hash(data: Data(content.utf8))
                .map { String(format: "%02x", $0) }
                .joined()
        }
    }

    static let defaultCapacity = 128

    private(set) var keys: Set<Key> = []
    private var order: [Key] = []
    private let capacity: Int

    init(capacity: Int = RAGInjectionDeduplication.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    func contains(_ key: Key) -> Bool {
        keys.contains(key)
    }

    mutating func record(_ key: Key) {
        guard keys.insert(key).inserted else { return }
        order.append(key)
        if order.count > capacity {
            keys.remove(order.removeFirst())
        }
    }
}
