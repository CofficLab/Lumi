import AppKit
import SwiftUI
import Testing
@testable import KitMarkdown

/// 代码块语法高亮的端到端断言。
///
/// 不变式：**Markdown 代码块必须以语法高亮呈现** —— 画面上要出现多种色相的
/// 着色文本，而不是一整块纯文本。
///
/// 断言只关心"渲染结果里有没有颜色"，不关心用哪种着色实现（正则、tree-sitter
/// 还是别的引擎），因此对实现方式保持开放；对照组（无语言标记的代码块、普通段落）
/// 用来排除"背景色/抗锯齿导致的假阳性"。
@MainActor
@Suite(.serialized)
struct CodeHighlightRenderingTests {

    /// 等待渲染落定的上限。
    ///
    /// 取值偏保守：测试会与其他用例并行、机器也可能正忙，取样+光栅化本身不便宜，
    /// 宁可多等也不要让"渲染还没落定"被误判成"没有着色"。
    private static let settleTimeout: Duration = .seconds(20)

    // MARK: - 端到端：画面像素

    @Test("带语言标记的代码块必须渲染出多种语法颜色")
    func codeBlockRendersSyntaxColors() async throws {
        let markdown = """
        ```swift
        let greeting = "hello"
        let count = 42
        ```
        """

        let families = try await hueFamilies(
            of: markdown,
            frame: CGSize(width: 420, height: 200),
            untilFamilyCount: 2,
            timeout: Self.settleTimeout
        )

        #expect(
            families.count >= 2,
            "代码块只渲染出 \(families.count) 种色相（\(families.sorted())），期望语法高亮的多色文本"
        )
    }

    @Test("无语言标记的代码块不应出现语法颜色（对照组）")
    func plainCodeBlockHasNoSyntaxColors() async throws {
        let markdown = """
        ```
        let greeting = "hello"
        let count = 42
        ```
        """

        let families = try await hueFamilies(
            of: markdown,
            frame: CGSize(width: 420, height: 200),
            untilFamilyCount: 1,
            timeout: .seconds(3)
        )

        #expect(
            families.isEmpty,
            "无语言标记的代码块不应着色，却出现 \(families.sorted())"
        )
    }

    @Test("普通段落不应出现语法颜色（对照组）")
    func plainParagraphHasNoSyntaxColors() async throws {
        let families = try await hueFamilies(
            of: "这是一段普通文本，不应该被着色。",
            frame: CGSize(width: 420, height: 200),
            untilFamilyCount: 1,
            timeout: .seconds(3)
        )

        #expect(
            families.isEmpty,
            "普通段落不应着色，却出现 \(families.sorted())"
        )
    }

    @Test("代码块内容变化后必须跟随更新并重新着色")
    func codeBlockFollowsContentChanges() async throws {
        let model = MarkdownSourceModel(markdown: """
        ```swift
        let a = 1
        ```
        """)

        let hosting = NSHostingView(rootView: MarkdownSourceView(model: model))
        hosting.frame = CGRect(origin: .zero, size: CGSize(width: 420, height: 240))
        hosting.layoutSubtreeIfNeeded()

        // 先等第一份高亮落地，确认"着色"这条链路本身是通的。
        var families = Set<Int>()
        let firstDeadline = ContinuousClock.now + Self.settleTimeout
        while ContinuousClock.now < firstDeadline {
            try await Task.sleep(for: .milliseconds(100))
            hosting.layoutSubtreeIfNeeded()
            families = Self.hueBuckets(in: hosting)
            if families.count >= 2 { break }
        }
        #expect(families.count >= 2, "首屏代码块应当被着色")

        let heightBefore = hosting.fittingSize.height

        // 换成更长的代码块：视图必须跟随新内容，而不是停在旧快照上。
        model.markdown = """
        ```swift
        let a = 1
        let b = 2
        let c = 3
        ```
        """

        var updated = false
        var refamilies = Set<Int>()
        let updateDeadline = ContinuousClock.now + Self.settleTimeout
        while ContinuousClock.now < updateDeadline {
            try await Task.sleep(for: .milliseconds(100))
            hosting.layoutSubtreeIfNeeded()
            if hosting.fittingSize.height > heightBefore + 1 {
                updated = true
                // 内容更新之后，新内容同样要能被着色：
                // 高亮不能卡在旧快照上（那样新内容会一直以纯文本呈现）。
                refamilies = Self.hueBuckets(in: hosting)
                if refamilies.count >= 2 { break }
            }
        }

        #expect(
            updated,
            "代码块内容变化后视图高度未更新（\(heightBefore) → \(hosting.fittingSize.height)），疑似停在旧快照"
        )
        #expect(
            refamilies.count >= 2,
            "内容更新后代码块没有重新着色（\(refamilies.sorted())）"
        )
    }

    // MARK: - 测试用宿主

    /// 可变 Markdown 源，用来模拟流式输出时的内容变化。
    @MainActor
    final class MarkdownSourceModel: ObservableObject {
        @Published var markdown: String
        init(markdown: String) { self.markdown = markdown }
    }

    private struct MarkdownSourceView: View {
        @ObservedObject var model: MarkdownSourceModel
        var body: some View {
            MarkdownBlockRenderer(markdown: model.markdown)
        }
    }

    // MARK: - 渲染辅助

    /// 渲染 Markdown 并统计画面上的色相分桶数量。
    ///
    /// `untilFamilyCount` 用于等待异步解析 + 异步高亮落地的轮询上界；
    /// 对照组传 1 表示"最多等到超时"就返回当前结果。
    private func hueFamilies(
        of markdown: String,
        frame: CGSize,
        untilFamilyCount: Int,
        timeout: Duration
    ) async throws -> Set<Int> {
        let hosting = NSHostingView(rootView: MarkdownBlockRenderer(markdown: markdown))
        hosting.frame = CGRect(origin: .zero, size: frame)
        hosting.layoutSubtreeIfNeeded()

        let deadline = ContinuousClock.now + timeout
        var families = Set<Int>()

        while ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(120))
            hosting.layoutSubtreeIfNeeded()
            families = Self.hueBuckets(in: hosting)
            if families.count >= untilFamilyCount { break }
        }

        return families
    }

    /// 把渲染像素按色相分桶；低饱和度（灰阶）像素不计。
    ///
    /// 抗锯齿会在纯色与背景之间产生大量中间色，因此按"色相分桶"而不是
    /// 精确 RGB 比较：同一语义的着色即使明暗不同，也应落在同一个桶里。
    ///
    /// 像素按 3×3 步长抽样 —— 色相统计不需要逐像素密度，
    /// 抽样能把每轮判定的开销降一个数量级（轮询本身要跑很多轮）。
    private static func hueBuckets(in hosting: NSView) -> Set<Int> {
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return [] }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        var buckets = Set<Int>()
        for y in stride(from: 0, to: rep.pixelsHigh, by: 3) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 3) {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                let r = color.redComponent
                let g = color.greenComponent
                let b = color.blueComponent
                let maxValue = max(r, g, b)
                let minValue = min(r, g, b)
                let delta = maxValue - minValue
                // 灰阶（背景、默认前景色、抗锯齿过渡）不计入色相。
                guard delta > 0.15 else { continue }

                var hue: CGFloat
                if maxValue == r {
                    hue = ((g - b) / delta) / 6
                } else if maxValue == g {
                    hue = ((b - r) / delta) / 6 + 2
                } else {
                    hue = ((r - g) / delta) / 6 + 4
                }
                if hue < 0 { hue += 1 }
                buckets.insert(Int(hue * 12) % 12)
            }
        }
        return buckets
    }
}
