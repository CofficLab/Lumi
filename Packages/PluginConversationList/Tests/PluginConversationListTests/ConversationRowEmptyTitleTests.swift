import Foundation
import ProviderConversation
import ProviderConversationState
import Testing
@testable import PluginConversationList

/// 复现：**对话列表中出现完全空白的条目。**
///
/// ## 现象
///
/// 会话列表里出现一个没有任何文字的行——标题空、副标题（provider·模型）
/// 空、项目名与时间也空，整行只剩一个色块。用户无法辨认这是什么对话，
/// 也无法按标题定位它。
///
/// ## 根因
///
/// `ConversationModel.title` 是**非可选** `String`，存储层用
/// `title?.trimming... ?? ""` 把「无标题」落库成空串（不是 NULL）。
///
/// 而会话行渲染用的是 `conversation.title ?? "对话"`——`??` 只兜得住
/// `nil`，兜不住空串。空串既不是 `nil`，`??` 不生效，于是渲染成空白。
///
/// 现有用例 `rowAccessibilityLabelFallsBackWhenTitleMissing` 只覆盖了
/// `title: nil`，**没有覆盖 `title: ""`**，所以这条路径一直没被测到。
///
/// ## 不变量
///
/// 一条会话行**永远不能是空的**：没有标题时必须有可辨认的占位文案。
/// 这条不变量对 `nil` 与 `""` 两种「无标题」形态同时成立。
///
/// - Note: 这些用例**现在应当失败**。它们是缺陷的复现，不是对现状的认可。
///   修复可以落在渲染侧（统一用 `displayTitle` 这类已归一的属性），
///   也可以落在数据侧（读回时把空串归一成 nil）——两者都能满足不变量。
@Suite("会话行的空标题处理")
struct ConversationRowEmptyTitleTests {

    /// 空字符串标题必须回退到占位文案，不得返回空串。
    ///
    /// 这是「空白行」缺陷在可访问性层面的表现：空 label 会让屏幕阅读器
    /// 跳过该行，UI 测试也无法按标题定位。
    @Test("空字符串标题回退为占位文案，不得返回空串")
    @MainActor
    func rowLabelFallsBackForEmptyStringTitle() {
        let row = ConversationListAccessibility.rowLabel(for: makeSummary(
            title: "",
            automationLevel: nil
        ))
        #expect(!row.isEmpty, "空标题的行不得产生空 label")
        #expect(row == "对话", "空字符串标题应回退为「对话」，实际「\(row)」")
    }

    /// 只含空白字符的标题同样属于「无标题」。
    ///
    /// 存储层写库前会 `trimmingCharacters(in: .whitespacesAndNewlines)`，
    /// 因此纯空白标题在库里就是空串；读回路径若不做归一，它会原样进入
    /// 渲染层。
    @Test("纯空白标题回退为占位文案")
    @MainActor
    func rowLabelFallsBackForWhitespaceOnlyTitle() {
        let row = ConversationListAccessibility.rowLabel(for: makeSummary(
            title: "   \n  ",
            automationLevel: nil
        ))
        #expect(!row.isEmpty, "纯空白标题的行不得产生空 label")
        #expect(row == "对话", "纯空白标题应回退为「对话」，实际「\(row)」")
    }

    /// 与 `nil` 形态保持一致：空串标题与 nil 标题必须得到同样的占位文案。
    ///
    /// 这条锁住「两种无标题形态收敛到同一结果」——否则修复只堵住其中
    /// 一种，另一种仍然产生空白行。
    @Test("空串标题与 nil 标题回退到同一占位文案")
    @MainActor
    func emptyStringAndNilTitlesConverge() {
        let fromEmpty = ConversationListAccessibility.rowLabel(for: makeSummary(
            title: "",
            automationLevel: nil
        ))
        let fromNil = ConversationListAccessibility.rowLabel(for: makeSummary(
            title: nil,
            automationLevel: nil
        ))
        #expect(
            fromEmpty == fromNil,
            "空串标题「\(fromEmpty)」与 nil 标题「\(fromNil)」应回退到同一占位文案"
        )
    }

    /// 有标题时不得被占位文案覆盖。
    ///
    /// 修复最容易引入的回归是「一刀切把所有标题替换成占位文案」。
    @Test("有标题时保持原样")
    @MainActor
    func nonEmptyTitleIsPreserved() {
        let row = ConversationListAccessibility.rowLabel(for: makeSummary(
            title: "真实标题",
            automationLevel: nil
        ))
        #expect(row == "真实标题", "实际「\(row)」")
    }
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
