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
    /// 每个回合已注入的证据正文，供同一回合的后续请求复用（#604）。
    private var evidence: [Key: String] = [:]
    private let capacity: Int

    init(capacity: Int = RAGInjectionDeduplication.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    func contains(_ key: Key) -> Bool {
        keys.contains(key)
    }

    /// 返回该回合已缓存的注入证据；nil 表示尚未注入或已被淘汰。
    func content(for key: Key) -> String? {
        evidence[key]
    }

    mutating func record(_ key: Key) {
        record(key, content: nil)
    }

    mutating func record(_ key: Key, content: String?) {
        guard keys.insert(key).inserted else {
            if let content { evidence[key] = content }
            return
        }
        order.append(key)
        if let content { evidence[key] = content }
        if order.count > capacity {
            let oldest = order.removeFirst()
            keys.remove(oldest)
            evidence.removeValue(forKey: oldest)
        }
    }
}
