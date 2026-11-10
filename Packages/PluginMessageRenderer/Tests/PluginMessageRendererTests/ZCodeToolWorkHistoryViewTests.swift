import CoreGraphics
import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageRenderer

/// V4（ZCode）工作工具历史契约测试。
///
/// 基准是 ZCode 3.15.1 计划第 2.6 节：
/// - 两个及以上连续 Explore/Execute 才形成父分组；单工具不额外套父层；
/// - ZCode 默认：Explore=true、Execute/Terminal=true、Changes=false、CUA=true；
///   Lumi 只映射真实存在的工具类型，找不到等价语义时保持独立工具行；
/// - 共享嵌套容器：左 margin 8、左边框、左 padding 14、子项间距 8；
/// - 摘要 14，图标通常 16，项间距 8，默认收起；
/// - Enter/Space 可展开，暴露 accessibilityExpanded 与可见键盘焦点；
/// - 展开内容与摘要间距 8；收起后 300ms 卸载重内容；
/// - 工具错误使用失败状态 + dotted underline + tooltip，不默认变成大红卡；
/// - Execute 摘要 command 用 sans；展开命令 mono 且带 `$`；
/// - Execute 输出 mono 14/20，最多 5 行内部滚动；离底超过 8 后停止输出跟随；
/// - Read 不展开结果；Edit 可展开 inline diff，最大高 240；通用工具预览最大高 240。
///
/// - Important: 必须复用 Lumi 现有 `ToolCallRowRenderer`、结果补全、授权状态
///   和 `ToolApprovalBridge`，不得用静态 ZCode 文案替换真实状态。
@Suite("ZCode 工作工具历史")
struct ZCodeToolWorkHistoryViewTests {

    // MARK: - 分组

    @Test("单个工具不形成父分组")
    func singleToolIsNotGrouped() {
        let tools = [makeTool(name: "Read", id: "t1")]

        #expect(ZCodeToolWorkHistoryStyle.shouldGroup(tools: tools) == false)
    }

    @Test("空工具不形成父分组")
    func emptyToolsAreNotGrouped() {
        #expect(ZCodeToolWorkHistoryStyle.shouldGroup(tools: []) == false)
    }

    @Test("两个以上连续 Explore/Execute 形成父分组")
    func consecutiveExploreExecuteAreGrouped() {
        let tools = [
            makeTool(name: "Explore", id: "t1"),
            makeTool(name: "Execute", id: "t2"),
        ]

        #expect(ZCodeToolWorkHistoryStyle.shouldGroup(tools: tools))
    }

    @Test("单个 Explore 不形成父分组")
    func singleExploreIsNotGrouped() {
        let tools = [makeTool(name: "Explore", id: "t1")]

        #expect(ZCodeToolWorkHistoryStyle.shouldGroup(tools: tools) == false)
    }

    @Test("跨正文的工具不合并")
    func toolsAcrossBodiesAreNotMerged() {
        // 分组判定只看**传入的同一批**工具，不按数组下标猜类型。
        let mixed = [
            makeTool(name: "Explore", id: "t1"),
            makeTool(name: "Read", id: "t2"),
        ]

        // Read 不属于 Explore/Execute 家族 → 不分组。
        #expect(ZCodeToolWorkHistoryStyle.shouldGroup(tools: mixed) == false)
    }

    @Test("Changes 类工具不参与 Explore/Execute 分组")
    func changesToolsAreNotGrouped() {
        let tools = [
            makeTool(name: "Write", id: "t1"),
            makeTool(name: "Write", id: "t2"),
        ]

        #expect(ZCodeToolWorkHistoryStyle.shouldGroup(tools: tools) == false)
    }

    @Test("未知工具名不参与分组")
    func unknownToolNamesAreNotGrouped() {
        let tools = [
            makeTool(name: "SomeBrandNewTool", id: "t1"),
            makeTool(name: "AnotherNewTool", id: "t2"),
        ]

        #expect(ZCodeToolWorkHistoryStyle.shouldGroup(tools: tools) == false)
    }

    // MARK: - 几何

    @Test("嵌套容器左 margin 8、左 padding 14、子项间距 8")
    func nestedContainerGeometry() {
        #expect(ZCodeToolWorkHistoryStyle.containerLeadingMargin == 8)
        #expect(ZCodeToolWorkHistoryStyle.containerLeadingPadding == 14)
        #expect(ZCodeToolWorkHistoryStyle.itemSpacing == 8)
    }

    @Test("摘要字号 14、图标 16")
    func summaryTypography() {
        #expect(ZCodeToolWorkHistoryStyle.summaryFontSize == 14)
        #expect(ZCodeToolWorkHistoryStyle.iconSize == 16)
    }

    @Test("展开内容与摘要间距 8")
    func expandedContentSpacing() {
        #expect(ZCodeToolWorkHistoryStyle.expandedContentSpacing == 8)
    }

    @Test("收起后 300ms 卸载重内容")
    func collapsedUnloadsAfter300ms() {
        #expect(ZCodeToolWorkHistoryStyle.unloadDelay == 0.3)
    }

    @Test("收起后重内容立即卸载")
    func collapsedUnloadsImmediately() {
        #expect(ZCodeToolWorkHistoryStyle.shouldUnloadHeavyContent(isExpanded: false) == true)
        #expect(ZCodeToolWorkHistoryStyle.shouldUnloadHeavyContent(isExpanded: true) == false)
    }

    // MARK: - Execute

    @Test("Execute 输出最多 5 行")
    func executeOutputMaxLinesIs5() {
        #expect(ZCodeToolWorkHistoryStyle.executeOutputMaxLines == 5)
    }

    @Test("Execute 输出离底超过 8 后停止跟随")
    func executeOutputFollowThresholdIs8() {
        #expect(ZCodeToolWorkHistoryStyle.executeOutputFollowThreshold == 8)
    }

    @Test("Execute 输出是 mono 14/20")
    func executeOutputTypography() {
        #expect(ZCodeToolWorkHistoryStyle.executeOutputFontSize == 14)
        #expect(ZCodeToolWorkHistoryStyle.executeOutputLineHeight == 20)
        #expect(ZCodeToolWorkHistoryStyle.executeOutputIsMonospaced == true)
    }

    // MARK: - 其它工具

    @Test("Read 不展开结果")
    func readDoesNotExpandResults() {
        #expect(ZCodeToolWorkHistoryStyle.expandsResult(toolName: "Read") == false)
    }

    @Test("Edit 可展开 inline diff")
    func editExpandsInlineDiff() {
        #expect(ZCodeToolWorkHistoryStyle.expandsResult(toolName: "Edit") == true)
    }

    @Test("通用工具预览最大高 240")
    func genericPreviewMaxHeightIs240() {
        #expect(ZCodeToolWorkHistoryStyle.genericPreviewMaxHeight == 240)
    }

    @Test("Edit 的 inline diff 最大高 240")
    func editDiffMaxHeightIs240() {
        #expect(ZCodeToolWorkHistoryStyle.editDiffMaxHeight == 240)
    }

    // MARK: - 工具名映射

    @Test("Explore/Execute/Terminal 归入可分组家族")
    func groupableFamilyMapping() {
        #expect(ZCodeToolWorkHistoryStyle.isGroupableFamily(toolName: "Explore"))
        #expect(ZCodeToolWorkHistoryStyle.isGroupableFamily(toolName: "Execute"))
        #expect(ZCodeToolWorkHistoryStyle.isGroupableFamily(toolName: "Terminal"))
    }

    @Test("Read/Write/Edit 不归入可分组家族")
    func nonGroupableFamilyMapping() {
        #expect(!ZCodeToolWorkHistoryStyle.isGroupableFamily(toolName: "Read"))
        #expect(!ZCodeToolWorkHistoryStyle.isGroupableFamily(toolName: "Write"))
        #expect(!ZCodeToolWorkHistoryStyle.isGroupableFamily(toolName: "Edit"))
    }

    @Test("工具名归一化忽略大小写")
    func familyMappingIsCaseInsensitive() {
        #expect(ZCodeToolWorkHistoryStyle.isGroupableFamily(toolName: "explore"))
        #expect(ZCodeToolWorkHistoryStyle.isGroupableFamily(toolName: "EXPLORE"))
    }

    @Test("展开命令带 $ 前缀且用 mono")
    func expandedCommandIsMonospacedWithDollarPrefix() {
        #expect(ZCodeToolWorkHistoryStyle.expandedCommandText("ls -la") == "$ ls -la")
        #expect(ZCodeToolWorkHistoryStyle.expandedCommandIsMonospaced == true)
    }

    @Test("摘要命令不使用 $ 前缀")
    func summaryCommandHasNoDollarPrefix() {
        #expect(ZCodeToolWorkHistoryStyle.summaryCommandText("ls -la") == "ls -la")
    }

    // MARK: - 辅助

    private func makeTool(name: String, id: String) -> MessageToolCall {
        MessageToolCall(id: id, name: name, arguments: "{}")
    }
}
