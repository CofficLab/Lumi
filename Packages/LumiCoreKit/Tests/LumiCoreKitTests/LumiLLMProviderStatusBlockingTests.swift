import Foundation
import Testing
@testable import LumiCoreKit

/// `LumiLLMProviderStatus.isBlocking` 是「Provider 可用性 gate」的单一判定源：
/// 依赖 Provider 的功能（子 Agent 工具、相关 UI）应在此级别拒绝注册。
///
/// 设计契约：
/// - `nil` → 不阻塞
/// - `.info` → 不阻塞（仅通知，不影响 Provider 实际可用性）
/// - `.warning` → **阻塞**（API Key 缺失、套餐过期等「能跑但跑不了」）
/// - `.error` → **阻塞**（平台不兼容等「完全不可用」）
@Suite struct LumiLLMProviderStatusBlockingTests {

    @Test func nilStatusIsNotBlocking() {
        // nil 直接视为健康，避免「无可用性告警」等于「阻塞」的误判。
        let status: LumiLLMProviderStatus? = nil
        let blocking: Bool = status?.isBlocking ?? false
        #expect(blocking == false)
    }

    @Test func infoLevelIsNotBlocking() {
        let status = LumiLLMProviderStatus(message: "provider release notes", level: .info)
        #expect(status.isBlocking == false,
                ".info 仅作通知，不应阻塞依赖该 Provider 的功能")
    }

    @Test func warningLevelIsBlocking() {
        let status = LumiLLMProviderStatus(message: "API Key not configured", level: .warning)
        #expect(status.isBlocking == true,
                ".warning 应阻塞，否则子 Agent 会被注册但每次调用都失败")
    }

    @Test func errorLevelIsBlocking() {
        let status = LumiLLMProviderStatus(message: "MLX 仅支持 Apple Silicon", level: .error)
        #expect(status.isBlocking == true,
                ".error 完全不可用，必须阻塞")
    }
}

/// 「Provider 可用」组合判定：`providerStatus()` → 子 Agent 是否应注册？
///
/// 这个测试保护 `providerStatus()?.isBlocking != true` 这条核心表达式的语义，
/// 防止有人误把 `== nil` 改为 `isBlocking` 反而阻断了本该通过的 `.info`。
@Suite struct ProviderAvailabilityGateTests {

    /// 模拟 `provider.providerStatus()?.isBlocking != true` 的最终判断。
    private func isAvailable(_ status: LumiLLMProviderStatus?) -> Bool {
        status?.isBlocking != true
    }

    @Test func gatePassesWhenStatusIsNil() {
        #expect(isAvailable(nil) == true, "nil 状态 → gate 通过")
    }

    @Test func gatePassesWhenStatusIsInfo() {
        let status = LumiLLMProviderStatus(message: "info", level: .info)
        #expect(isAvailable(status) == true, ".info → gate 通过")
    }

    @Test func gateBlocksOnWarning() {
        let status = LumiLLMProviderStatus(message: "no key", level: .warning)
        #expect(isAvailable(status) == false, ".warning → gate 拒绝")
    }

    @Test func gateBlocksOnError() {
        let status = LumiLLMProviderStatus(message: "platform", level: .error)
        #expect(isAvailable(status) == false, ".error → gate 拒绝")
    }
}
