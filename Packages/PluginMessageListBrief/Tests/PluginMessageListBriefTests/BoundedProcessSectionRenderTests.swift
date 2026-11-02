import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区限高的**渲染级**验证。
///
/// ## 为什么必须做渲染级验证
///
/// 限高的全部语义都建立在一条几何事实上：
///
/// > `ScrollView` 配 `.frame(maxHeight:)` 的固有高度 = min(内容高度, 上限)
///
/// 这不是 SwiftUI 文档里的承诺，而是本项目的实现依赖。如果哪天这个行为
/// 变了（例如 `ScrollView` 改成总是占满提案高度），折叠区就会退化成
/// 「永远占满 60% 视口」，短内容也要拖着一大片空白 —— 而单元测试
/// （只测纯函数）完全发现不了这种退化。
///
/// 因此这里渲染**真实的 `List`**，量真实行高。
@MainActor
@Suite("过程折叠区限高的渲染级测试")
struct BoundedProcessSectionRenderTests {
    /// 在真实 `List` 里渲染若干行，返回每行的高度。
    ///
    /// - Parameters:
    ///   - lineCounts: 每行的内容行数。
    ///   - maxHeight: 折叠区的高度上限。
    private func measureRowHeights(
        lineCounts: [Int],
        maxHeight: CGFloat
    ) throws -> [CGFloat] {
        let hosting = NSHostingView(
            rootView: ProbeList(lineCounts: lineCounts, maxHeight: maxHeight)
        )
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 900)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 900),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(hosting)
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()

        // 让 List 完成一次布局（行高是异步算出来的）。
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))

        let tableView = try #require(findTableView(in: hosting), "未找到 NSTableView")
        defer {
            window.orderOut(nil)
            hosting.removeFromSuperview()
        }

        return (0..<tableView.numberOfRows).map { row in
            tableView.rect(ofRow: row).height
        }
    }

    private func findTableView(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for sub in view.subviews {
            if let found = findTableView(in: sub) { return found }
        }
        return nil
    }

    // MARK: - 用例

    @Test("内容超过上限时，行高封顶在上限附近（不随内容增长）")
    func overflowingContentIsCapped() throws {
        let maxHeight: CGFloat = 200
        let heights = try measureRowHeights(lineCounts: [50, 100], maxHeight: maxHeight)

        #expect(heights.count == 2)
        for (index, height) in heights.enumerated() {
            #expect(
                height <= maxHeight + 8,
                """
                第 \(index) 行内容远超上限（50/100 行），行高应为 \(maxHeight) 附近，\
                实测 \(height)pt —— 限高未生效，内容把行撑开了。
                """
            )
        }
        #expect(
            abs(heights[0] - heights[1]) < 1,
            """
            50 行与 100 行的内容都已超出上限，行高应相同；\
            实测 \(heights[0])pt vs \(heights[1])pt —— 行高仍随内容增长。
            """
        )
    }

    @Test("内容短于上限时，行高随内容自适应（不占满上限）")
    func shortContentUsesContentHeight() throws {
        let maxHeight: CGFloat = 400
        let heights = try measureRowHeights(lineCounts: [3, 8], maxHeight: maxHeight)

        #expect(heights.count == 2)
        for (index, height) in heights.enumerated() {
            #expect(
                height < maxHeight,
                """
                第 \(index) 行内容很短（3/8 行），行高应自适应而非占满上限 \(maxHeight)，\
                实测 \(height)pt。
                """
            )
        }
        #expect(
            heights[1] > heights[0],
            """
            8 行内容应比 3 行更高；实测 \(heights[0])pt vs \(heights[1])pt。
            """
        )
    }
}

/// 探针列表：每行是一个限高容器，内容行数由 `lineCounts` 决定。
private struct ProbeList: View {
    let lineCounts: [Int]
    let maxHeight: CGFloat

    var body: some View {
        List {
            ForEach(Array(lineCounts.enumerated()), id: \.offset) { _, count in
                ProbeSection(lines: count, maxHeight: maxHeight)
            }
        }
        .listStyle(.plain)
    }
}

/// 探针折叠区：内容是若干个固定高度的行，外面套上限。
private struct ProbeSection: View {
    let lines: Int
    let maxHeight: CGFloat

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<lines, id: \.self) { index in
                    Text("line-\(index)")
                        .frame(height: 20)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: maxHeight)
    }
}
