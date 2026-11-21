import Testing

@testable import PluginLLMContext

/// #610：工具栏用量颜色与弹窗 `ContextUsageRing` 必须同口径。
///
/// 环把 75% / 90% 阈值套在 `estimatedInputTokens / inputTokenLimit` 上
/// （输入预算扣除了输出预留、工具 schema 与安全边际）；工具栏旧实现用
/// 完整窗口大小做分母，同一个快照会显示更轻的严重程度。
@Suite struct ContextToolbarSeverityTests {

    /// issue 复现：窗口 128k、预算 112k、已用 105k。
    /// 旧口径 105k/128k ≈ 82% 只有警告；预算口径 105k/112k ≈ 94% 是危险。
    @Test("分母用输入预算，逼近发送预算时升级为危险档")
    func criticalSeverityUsesInputBudget() {
        #expect(ContextToolbarView.usageSeverity(used: 105_000, limit: 112_000) == 2)
        #expect(ContextToolbarView.usageSeverity(used: 105_000, limit: 128_000) == 1)
    }

    @Test("阈值边界与无效输入退回正常档")
    func severityBoundaries() {
        #expect(ContextToolbarView.usageSeverity(used: 0, limit: 112_000) == 0)
        #expect(ContextToolbarView.usageSeverity(used: 1_000, limit: 0) == 0)
        #expect(ContextToolbarView.usageSeverity(used: 74, limit: 100) == 0)
        #expect(ContextToolbarView.usageSeverity(used: 75, limit: 100) == 1)
        #expect(ContextToolbarView.usageSeverity(used: 89, limit: 100) == 1)
        #expect(ContextToolbarView.usageSeverity(used: 90, limit: 100) == 2)
    }
}
