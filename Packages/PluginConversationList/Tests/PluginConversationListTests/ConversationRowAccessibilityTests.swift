import Foundation
import ProviderConversation
import ProviderConversationState
import Testing
@testable import PluginConversationList

/// 会话行的可访问性名称（`accessibilityLabel`）验证。
///
/// ## 为什么这层值得测
///
/// 会话行此前**完全没有** accessibility 修饰，导致两个同源后果：
/// 屏幕阅读器读不到标题（真实无障碍缺陷）、UI 测试无法按标题定位行。
/// 修复方式是给出行级 label + 标识符。
///
/// label 的组装规则有个易错点：**标题必须排在最前且一定在场**。
/// 若只依赖 `.accessibilityElement(children: .combine)`，子元素过多时
/// SwiftUI 可能截断拼接而丢掉标题；因此额外显式赋值。这条规则必须有测试
/// 兜住，否则重构时很容易退回「只 combine、不显式赋值」而无人察觉。
@Test @MainActor func rowAccessibilityLabelAlwaysStartsWithTitle() {
    #expect(ConversationListAccessibility.itemID == "lumi.conversation-list.item")
    #expect(ConversationListAccessibility.listID == "lumi.conversation-list")

    // 最小场景：只有标题（无等级时）。
    let bare = ConversationListAccessibility.rowLabel(for: makeSummary(
        title: "只有标题",
        automationLevel: nil
    ))
    #expect(bare == "只有标题", "label 应等于标题，实际「\(bare)」")

    // 标题 + provider + 模型：标题仍必须在最前。
    let full = ConversationListAccessibility.rowLabel(for: makeSummary(
        title: "会话 A",
        providerID: "anthropic",
        modelName: "claude"
    ))
    #expect(full == "会话 A anthropic claude 构建", "实际「\(full)」")
    #expect(full.hasPrefix("会话 A"), "标题必须排在 label 最前，实际「\(full)」")
}

/// 自动化等级必须出现在 label 中。
///
/// 等级标签位于第三行末尾（项目 · 时间 之后）。虽然行内已有 `.combine`，
/// 但子元素过多时 SwiftUI 会截断拼接，因此等级必须由 `rowLabel` 显式补回，
/// 保证屏幕阅读器与 UI 测试都能稳定拿到它。
@Test @MainActor func rowAccessibilityLabelIncludesAutomationLevel() {
    for level in AutomationLevel.allCases {
        let row = ConversationListAccessibility.rowLabel(for: makeSummary(
            title: "会话 C",
            automationLevel: level
        ))
        #expect(
            row == "会话 C \(level.displayName)",
            "等级「\(level.displayName)」应出现在 label 中，实际「\(row)」"
        )
    }
}

/// 无标题时回退到「对话」，且不得返回空字符串。
///
/// 空 label 会让屏幕阅读器跳过该行，也让 UI 测试无法定位 —— 是同一个缺陷的两面。
@Test @MainActor func rowAccessibilityLabelFallsBackWhenTitleMissing() {
    let row = ConversationListAccessibility.rowLabel(for: makeSummary(
        title: nil,
        automationLevel: nil
    ))
    #expect(row == "对话", "无标题时应回退为「对话」，实际「\(row)」")
    #expect(!row.isEmpty, "label 不得为空串")
}

/// 空字符串的 provider / 模型不得污染 label。
///
/// `ConversationSummary` 允许空串入库；直接拼接会产生 `"会话 B  "` 这类
/// 带多余空格的名称，破坏按标题精确定位的测试。
@Test @MainActor func rowAccessibilityLabelSkipsEmptyProviderAndModel() {
    let row = ConversationListAccessibility.rowLabel(for: makeSummary(
        title: "会话 B",
        providerID: "",
        modelName: "",
        automationLevel: nil
    ))
    #expect(row == "会话 B", "空 provider/模型应被跳过，实际「\(row)」")
}

// MARK: - Helpers

private func makeSummary(
    title: String?,
    providerID: String? = nil,
    modelName: String? = nil,
    automationLevel: AutomationLevel? = .build
) -> ConversationSummary {
    let now = Date()
    return ConversationSummary(
        id: UUID(),
        title: title,
        preview: "",
        createdAt: now,
        updatedAt: now,
        verbosity: .standard,
        reasoningEffort: nil,
        language: .chinese,
        automationLevel: automationLevel,
        providerID: providerID,
        modelName: modelName,
        projectPath: nil,
        parentConversationID: nil
    )
}
