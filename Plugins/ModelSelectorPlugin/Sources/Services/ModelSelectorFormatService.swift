import Foundation
import LumiKernel
import LumiKernel

/// 格式化逻辑现位于 `LumiChatKit.TokenCountFormat`, 这里保留旧名以减少调用点改动。
enum ModelSelectorFormatService {
    static func tps(_ tps: Double) -> String {
        TokenCountFormat.tps(tps)
    }

    static func contextSize(_ tokens: Int) -> String {
        TokenCountFormat.contextSize(tokens)
    }

    static func tokenCount(_ tokens: Int) -> String {
        TokenCountFormat.tokenCount(tokens)
    }
}
