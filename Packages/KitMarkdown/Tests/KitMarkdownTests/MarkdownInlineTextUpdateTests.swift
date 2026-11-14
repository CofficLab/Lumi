import AppKit
import SwiftUI
import Testing
import KitMarkdown

/// 行内富文本视图的内容跟随契约。
///
/// 不变式：**同一段落的文本变化（流式追加 / 原位替换）后，渲染结果必须跟随
/// 新内容**，不能停在首次解析的旧快照上。视图 identity 在流式期间保持稳定
/// （块级 ForEach 按 offset 标识），因此视图内部缓存的解析结果必须自带
/// 来源校验 —— 与 `HighlightedCodeView` 的 `highlighted.source == code` 同契约。
///
/// 观测手段：首段用链接 `[短文本](超长 URL)`。未解析时按字面渲染整段 URL
/// （多行、高）；行内解析落地后只剩链接文字（一行、矮）。高度跌落证明
/// 异步解析确实落地（排除"任务没跑 → 纯文本回退恰好跟随"的假绿），
/// 随后再让段落增长/替换，断言高度必须再次跟上。
@MainActor
@Suite(.serialized)
struct MarkdownInlineTextUpdateTests {

    private static let settleTimeout: Duration = .seconds(20)
    private static let contentWidth: CGFloat = 300

    @Test("流式追加后段落必须跟随新内容渲染")
    func inlineTextFollowsStreamingAppend() async throws {
        let model = InlineTextSourceModel(markdown: Self.linkParagraph(label: "首段"))
        try await withHostedRenderer(model: model) { hosting in
            try await Self.waitForFirstParse(hosting)
            let parsedHeight = hosting.fittingSize.height

            // 同一段落尾部追加（无空行 → 块数不变 → 视图 identity 不变），
            // 模拟流式输出的逐 token 增长。
            model.markdown += String(repeating: "流式输出不断增长。", count: 30)

            let grew = try await Self.poll(hosting) {
                hosting.fittingSize.height > parsedHeight + 60
            }
            #expect(
                grew,
                "段落追加后高度未增长（\(parsedHeight) → \(hosting.fittingSize.height)），行内文本停在旧快照"
            )
        }
    }

    @Test("原位替换段落后必须渲染新内容")
    func inlineTextFollowsInPlaceReplacement() async throws {
        let model = InlineTextSourceModel(markdown: Self.linkParagraph(label: "替换段"))
        try await withHostedRenderer(model: model) { hosting in
            try await Self.waitForFirstParse(hosting)
            let parsedHeight = hosting.fittingSize.height

            // 整段换成更长的新内容（重试覆盖 / 重写场景）：
            // 块数仍为 1，视图 identity 不变。
            model.markdown = String(repeating: "原位替换后的新内容。", count: 30)

            let grew = try await Self.poll(hosting) {
                hosting.fittingSize.height > parsedHeight + 60
            }
            #expect(
                grew,
                "段落替换后高度未增长（\(parsedHeight) → \(hosting.fittingSize.height)），行内文本停在旧快照"
            )
        }
    }

    // MARK: - 宿主

    @MainActor
    private final class InlineTextSourceModel: ObservableObject {
        @Published var markdown: String
        init(markdown: String) { self.markdown = markdown }
    }

    private struct InlineTextSourceView: View {
        @ObservedObject var model: InlineTextSourceModel
        var body: some View {
            MarkdownBlockRenderer(markdown: model.markdown)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: MarkdownInlineTextUpdateTests.contentWidth, alignment: .leading)
        }
    }

    /// 入窗宿主：保证 `.task` 异步解析真实执行（headless 宿主可能取消任务）。
    private func withHostedRenderer(
        model: InlineTextSourceModel,
        _ body: (NSHostingView<InlineTextSourceView>) async throws -> Void
    ) async throws {
        let hosting = NSHostingView(rootView: InlineTextSourceView(model: model))
        hosting.frame = CGRect(origin: .zero, size: CGSize(width: Self.contentWidth, height: 2_000))
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        hosting.layoutSubtreeIfNeeded()
        try await body(hosting)
    }

    // MARK: - 观测辅助

    /// 链接首段：字面渲染是长 URL（多行），解析落地后只剩链接文字（一行）。
    private static func linkParagraph(label: String) -> String {
        "[\(label)](https://example.com/\(String(repeating: "path-segment/", count: 20)))"
    }

    /// 等到高度跌落到单行区间，证明行内异步解析已落地。
    private static func waitForFirstParse(
        _ hosting: NSView
    ) async throws {
        let landed = try await poll(hosting) {
            let height = hosting.fittingSize.height
            return height > 1 && height < 45
        }
        #expect(landed, "首次行内解析未在超时内落地，无法验证后续内容跟随")
    }

    /// 轮询布局直到条件成立或超时；每轮强制同步布局后取样。
    private static func poll(
        _ hosting: NSView,
        until condition: () -> Bool
    ) async throws -> Bool {
        let deadline = ContinuousClock.now + settleTimeout
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
            hosting.layoutSubtreeIfNeeded()
            if condition() { return true }
        }
        hosting.layoutSubtreeIfNeeded()
        return condition()
    }
}