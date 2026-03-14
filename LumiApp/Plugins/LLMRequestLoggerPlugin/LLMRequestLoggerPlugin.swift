import Foundation
import MagicKit

/// LLM 请求日志插件
actor LLMRequestLoggerPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "📡"
    nonisolated static let verbose = false

    static let id: String = "LLMRequestLoggerPlugin"
    static let displayName: String = "LLM Request Logger"
    static let description: String = "记录所有与 LLM 的 HTTP 请求到插件自有 SwiftData 数据库。"
    static let iconName: String = "waveform.path.ecg"

    /// 用户不可配置，始终启用
    static let isConfigurable: Bool = false
    static let enable: Bool = true

    /// 放在辅助插件区间
    static var order: Int { 520 }

    nonisolated func onRegister() {
        LLMRequestLoggerCenter.shared.register(logger: LLMRequestLogStore.shared)
    }
}

