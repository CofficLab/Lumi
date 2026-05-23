import Foundation
import LLMKit

/// LLM 配置获取协议
@MainActor
public protocol SuperLLMConfigProvider: AnyObject {
    func getCurrentConfig() -> LLMConfig
}
