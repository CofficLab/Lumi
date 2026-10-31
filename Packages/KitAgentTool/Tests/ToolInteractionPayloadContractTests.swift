import Foundation
import Testing
@testable import KitAgentTool

/// 复现：**工具挂起载荷的契约在多个包之间不一致，导致授权载荷解码必然失败。**
///
/// ## 症状
///
/// 授权卡片渲染不出正确内容，界面退化成兜底文案。
///
/// ## 根因
///
/// 载荷是「执行层 → 交互层」的跨层契约，但它没有归属：过去在四个包里
/// 各抄了一份 `private` 副本。其中两份带显式 CodingKeys（编码出
/// `toolCallId`），两份不带（编码出 `toolCallID`）。
///
/// 消费端只认 `toolCallId`，于是**生产环境实际使用的那个生产者**
/// （`PluginToolManager`，它替换了默认实现）产出的载荷解码必然失败。
///
/// 契约检查必须锁住两件事：
///
/// 1. **编码键名统一**——所有生产者写出的 JSON 必须能被消费端解出来；
/// 2. **编解码可逆**——编码再解码必须拿回同样的值。
///
/// 这一层锁住什么
///
/// 本文件锁住**契约本身的形状**，不涉及任何具体生产者。各生产者改用
/// `ToolInteractionPayload` 后，键名漂移就不可能再发生——这是把契约
/// 收敛到唯一归属的根本原因。
@Suite("工具挂起载荷的契约一致性")
struct ToolInteractionPayloadContractTests {

    // MARK: - 键名

    /// 编码必须写出 `toolCallId`（小写 d）。
    ///
    /// 这是消费端历史上唯一认识的键名。任何改名都会让授权载荷静默解码失败，
    /// 而失败的表现是「界面退化成兜底文案」——极难归因。
    @Test("编码写出的键名是 toolCallId")
    func encodedKeyIsLowercaseD() {
        let payload = ToolInteractionPayload.permission(
            toolCallID: "approval:call-1",
            riskLevelName: "高风险",
            operation: "写入 /tmp/a.txt"
        )
        let json = payload.encoded()

        #expect(json.contains("\"toolCallId\""), "载荷未写出 toolCallId：\(json)")
        #expect(
            !json.contains("\"toolCallID\""),
            "载荷写出了大写 D 的 toolCallID，消费端解不出来：\(json)"
        )
    }

    /// 消费端必须能解出生产者写出的内容。
    ///
    /// 这是端到端的契约断言：编 → 解必须拿回同样的值。
    @Test("编码后可以被解码回同样的值")
    func roundTripPreservesValues() {
        let payload = ToolInteractionPayload.permission(
            toolCallID: "approval:call-2",
            riskLevelName: "高风险",
            operation: "写入 /tmp/a.txt"
        )

        let decoded = ToolInteractionPayload.decodePermission(from: payload.encoded())

        #expect(decoded != nil, "自己编码的载荷解不回来")
        #expect(decoded?.toolCallID == payload.toolCallID)
        #expect(decoded?.kind == payload.kind)
        #expect(decoded?.question == payload.question)
        #expect(decoded?.options == payload.options)
        #expect(decoded?.mode == payload.mode)
    }

    /// 历史生产者写出的大写 D 键名仍可被读取。
    ///
    /// 历史数据（以及仍在运行的老版本进程写出的载荷）用的是 `toolCallID`。
    /// 解码必须容忍它，否则升级后旧的挂起载荷会全部失效。
    @Test("兼容历史的大写 D 键名")
    func decodesLegacyUppercaseKey() {
        let legacy = #"{"toolCallID":"approval:call-3","kind":"permission","question":"是否允许？","options":["允许","拒绝"],"mode":"yes_no"}"#

        let decoded = ToolInteractionPayload.decodePermission(from: legacy)

        #expect(decoded != nil, "历史载荷（大写 D 键名）解不出来")
        #expect(decoded?.toolCallID == "approval:call-3")
        #expect(decoded?.question == "是否允许？")
    }

    // MARK: - 种类判据

    /// 非授权载荷不得被当成授权请求。
    ///
    /// `ask_user` 的提问载荷没有 `kind` 字段；把它误判成授权请求，
    /// 通用授权卡片就会接管这条工具行并渲染出错误文案。
    @Test("无 kind 的交互载荷不是授权请求")
    func interactionPayloadIsNotPermissionRequest() {
        let askUser = #"{"toolCallId":"ask_user","question":"继续吗？","options":[],"mode":"yes_no"}"#

        #expect(!ToolSuspensionKind.isPermissionRequest(askUser))
        #expect(!ToolSuspensionKind.isAuthorizationRequest(askUser))
        #expect(ToolInteractionPayload.decodePermission(from: askUser) == nil)
    }

    /// Computer Use 的应用授权载荷是**授权**请求，但不是**通用**授权请求。
    ///
    /// 两者都需要 `pendingAuthorization`（都在等用户做授权决定），
    /// 但只有通用授权请求该由通用授权卡片渲染——Computer Use 有自己的卡片
    /// （「允许一次 / 始终允许 / 拒绝」）。
    @Test("Computer Use 授权载荷是授权但不是通用授权")
    func computerUsePayloadIsAuthorizationButNotPermission() {
        let computerUse = #"{"kind":"computer_use_authorization","request":{"applicationName":"App Store","bundleIdentifier":"com.apple.AppStore","operation":"accessibility_observe"},"options":["allowOnce","alwaysAllow","deny"]}"#

        #expect(ToolSuspensionKind.isAuthorizationRequest(computerUse))
        #expect(!ToolSuspensionKind.isPermissionRequest(computerUse))
    }

    /// 通用授权载荷必须被两条判据同时认可。
    @Test("通用授权载荷同时满足两种判据")
    func permissionPayloadSatisfiesBothPredicates() {
        let permission = ToolInteractionPayload.permission(
            toolCallID: "approval:call-4",
            riskLevelName: "高风险",
            operation: "删除文件"
        ).encoded()

        #expect(ToolSuspensionKind.isPermissionRequest(permission))
        #expect(ToolSuspensionKind.isAuthorizationRequest(permission))
        #expect(ToolSuspensionKind.hasStructuredPayload(permission))
    }

    /// 非结构化内容（纯文本旧数据）必须被判为「无法判别」。
    ///
    /// 它不是「结构化但不是授权」，而是「根本不是载荷」。两种情况的处理
    /// 方式不同：前者要断言「不是授权请求」，后者只能交给兜底路径。
    @Test("纯文本内容不是结构化载荷")
    func plainTextIsNotStructuredPayload() {
        #expect(!ToolSuspensionKind.hasStructuredPayload("approval"))
        #expect(!ToolSuspensionKind.hasStructuredPayload(""))
        #expect(!ToolSuspensionKind.hasStructuredPayload(nil))
        #expect(!ToolSuspensionKind.hasStructuredPayload("[1,2,3]"))
    }
}
