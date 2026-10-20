import Foundation
import os

/// MiniMax 的共享常量。
enum MiniMaxSharedConstants {
    /// API Key 的 Keychain storage key。
    ///
    /// 聊天请求与 Token Plan 配额查询共用这一份 Key，因此集中定义，
    /// 避免两处字面量漂移。
    nonisolated static let apiKeyStorageKey = "DevAssistant_ApiKey_MiniMax"
}
