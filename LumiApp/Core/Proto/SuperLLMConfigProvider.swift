import Foundation
import MagicKit

/// LLM 配置获取协议
@MainActor
protocol SuperLLMConfigProvider: AnyObject {
    func getCurrentConfig() -> LLMConfig
}
