import Testing
import Foundation
import KernelCore
import KitAgentTool
import ProviderMessage
import ProviderMessageRendering
@testable import PluginAppStoreConnect

// MARK: - Helpers

/// 构造一份典型的提交快照，供各用例复用。
private func makePreview(
    stage: ASCSubmissionStage = .preview
) -> ASCSubmissionPreview {
    ASCSubmissionPreview(
        appName: "Lumi",
        versionID: "v-123",
        versionString: "1.2.0",
        platform: "IOS",
        platformLabel: "iOS",
        appStoreState: "PREPARE_FOR_SUBMISSION",
        appVersionState: "PREPARE_FOR_SUBMISSION",
        releaseType: "AFTER_APPROVAL",
        buildNumber: "45",
        buildVersionString: "1.2.0",
        buildProcessingState: "VALID",
        localizations: [
            ASCSubmissionLocalization(
                locale: "en-US",
                hasDescription: true,
                hasWhatsNew: true,
                hasKeywords: true,
                isDescriptionEmpty: false
            ),
            ASCSubmissionLocalization(
                locale: "zh-Hans",
                hasDescription: false,
                hasWhatsNew: true,
                hasKeywords: true,
                isDescriptionEmpty: true
            )
        ],
        warnings: ["Localization 'zh-Hans' has an empty description."],
        stage: stage
    )
}

// MARK: - Preview model

@Test("提交快照的 Build 展示标签拼接预发布版本号与构建号")
func submissionPreviewBuildLabel() {
    let preview = makePreview()
    #expect(preview.buildDisplayLabel == "1.2.0 (45)")

    var withoutPreRelease = preview
    withoutPreRelease.buildVersionString = nil
    #expect(withoutPreRelease.buildDisplayLabel == "45")

    var withoutBuild = preview
    withoutBuild.buildNumber = nil
    #expect(withoutBuild.buildDisplayLabel == nil)
}

@Test("提交快照汇总本地化区域码并标记风险提示")
func submissionPreviewSummaries() {
    let preview = makePreview()

    #expect(preview.localeLabels == ["en-US", "zh-Hans"])
    #expect(preview.hasWarnings)
    #expect(!ASCSubmissionPreview(
        versionID: "v",
        versionString: "1.0",
        platform: "IOS",
        platformLabel: "iOS",
        appStoreState: "-",
        appVersionState: "-"
    ).hasWarnings)
}

@Test("提交快照经过 JSON 编解码后保持一致")
func submissionPreviewCodableRoundTrip() throws {
    let preview = makePreview(stage: .submitted)
    let data = try JSONEncoder().encode(preview)
    let decoded = try JSONDecoder().decode(ASCSubmissionPreview.self, from: data)

    #expect(decoded == preview)
    #expect(decoded.stage == .submitted)
}

// MARK: - Timeline message

@Test("提交时间线消息携带专属渲染类型与渲染器 ID")
func submissionTimelineMessageShape() {
    let conversationID = UUID()
    let turnID = UUID()
    let message = ASCSubmissionTimeline.message(
        conversationID: conversationID,
        turnID: turnID,
        preview: makePreview()
    )

    #expect(message.conversationID == conversationID)
    #expect(message.turnID == turnID)
    #expect(message.renderKind == MessageTimelineEvent.appStoreSubmissionRenderKind)
    #expect(message.preferredRendererID == ASCSubmissionTimeline.rendererID)
    #expect(message.metadata[MessageTimelineEvent.metadataKey] == MessageTimelineEvent.appStoreSubmission)
    #expect(ASCSubmissionTimeline.stage(from: message.metadata) == .preview)
}

@Test("提交时间线消息的正文摘要区分提交前与提交后")
func submissionTimelineSummaryText() {
    let previewMessage = ASCSubmissionTimeline.message(
        conversationID: UUID(),
        turnID: nil,
        preview: makePreview(stage: .preview)
    )
    #expect(previewMessage.content.contains("1.2.0"))
    #expect(previewMessage.content.contains("iOS"))

    let submittedMessage = ASCSubmissionTimeline.message(
        conversationID: UUID(),
        turnID: nil,
        preview: makePreview(stage: .submitted)
    )
    #expect(submittedMessage.content != previewMessage.content)
}

@Test("提交时间线消息的结构化载荷可从 metadata 还原")
func submissionTimelinePayloadRoundTrip() {
    let preview = makePreview()
    let message = ASCSubmissionTimeline.message(
        conversationID: UUID(),
        turnID: nil,
        preview: preview
    )

    let decoded = ASCSubmissionTimeline.decodePreview(from: message.metadata)
    #expect(decoded == preview)
    #expect(decoded?.versionString == "1.2.0")
    #expect(decoded?.buildNumber == "45")
    #expect(decoded?.platformLabel == "iOS")
    #expect(decoded?.appStoreState == "PREPARE_FOR_SUBMISSION")
    #expect(decoded?.localeLabels == ["en-US", "zh-Hans"])
}

@Test("提交时间线消息的载荷缺失时返回 nil 而不是崩溃")
func submissionTimelinePayloadMissing() {
    #expect(ASCSubmissionTimeline.decodePreview(from: [:]) == nil)
    #expect(ASCSubmissionTimeline.decodePreview(from: [ASCSubmissionTimeline.payloadKey: "not-json"]) == nil)
    #expect(ASCSubmissionTimeline.stage(from: [:]) == nil)
}

// MARK: - LLM context filtering

@Test("提交时间线消息被判定为时间线事件，不回流 LLM")
func submissionTimelineIsExcludedFromLLMContext() {
    let message = ASCSubmissionTimeline.message(
        conversationID: UUID(),
        turnID: nil,
        preview: makePreview()
    )

    #expect(MessageTimelineEvent.isAppStoreSubmission(message))
    #expect(MessageTimelineEvent.isTimelineEvent(message))
}

@Test("普通系统消息不会被误判为提交时间线事件")
func regularMessageIsNotSubmissionTimelineEvent() {
    let message = Message(
        conversationID: UUID(),
        role: .system,
        content: "普通系统消息"
    )

    #expect(!MessageTimelineEvent.isAppStoreSubmission(message))
    #expect(!MessageTimelineEvent.isTimelineEvent(message))
}

// MARK: - Renderer

@MainActor
@Test("提交审核渲染器可以接管提交时间线消息")
func submissionRendererMatchesSubmissionMessage() {
    let renderer = ASCSubmissionRenderer.item()
    let message = ASCSubmissionTimeline.message(
        conversationID: UUID(),
        turnID: nil,
        preview: makePreview()
    )

    #expect(renderer.id == ASCSubmissionTimeline.rendererID)
    #expect(renderer.canRender(message))
    #expect(!renderer.canRender(Message(
        conversationID: UUID(),
        role: .system,
        content: "普通系统消息"
    )))
}

@MainActor
@Test("提交审核渲染器的优先级高于通用兜底渲染器")
func submissionRendererOrderBeatsDefault() {
    let renderer = ASCSubmissionRenderer.item()

    // `core-default-markdown` 是兜底渲染器，order 极低；
    // 提交审核卡片必须优先于它被渲染。
    #expect(renderer.order > 0)
}

@MainActor
@Test("插件启动时注册提交审核渲染器，关闭时注销")
func pluginRegistersSubmissionRenderer() throws {
    let kernel = KernelCoreContainer()
    let rendering = DefaultMessageRenderingProviding()
    try kernel.registerProvider((any MessageRenderingProviding).self, rendering)

    let plugin = AppStoreConnectPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(rendering.allRenderers.contains { $0.id == ASCSubmissionTimeline.rendererID })

    try plugin.onShutdown(kernel: kernel)
    #expect(!rendering.allRenderers.contains { $0.id == ASCSubmissionTimeline.rendererID })
}

// MARK: - Tool

@MainActor
@Test("提交审核工具在缺少会话上下文时不产生时间线消息")
func submitToolWithoutContextProducesNoTimelineMessage() async throws {
    let tool = SubmitAppStoreConnectVersionTool()
    let context = ToolExecutionContext(
        jobID: "job-1",
        conversationID: UUID()
    )

    // 缺少 ASC 凭据时工具会提前失败，不会走到产生时间线消息的路径；
    // 这里只验证「无上下文入口」不抛异常且返回错误结果。
    let result = try await tool.executeResult(context: context, arguments: [:])
    #expect(result.isError)
    #expect(result.content.contains("versionID"))
}
