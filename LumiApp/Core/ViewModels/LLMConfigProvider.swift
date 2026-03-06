import Foundation
import MagicKit

/// LLM 配置获取协议
/// 用于解耦 MessageSenderViewModel 和 AgentProvider
@MainActor
protocol LLMConfigProvider: AnyObject {
    func getCurrentConfig() -> LLMConfig
}