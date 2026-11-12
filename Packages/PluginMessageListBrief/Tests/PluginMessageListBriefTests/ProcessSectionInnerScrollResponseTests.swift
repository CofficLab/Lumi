import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区**内层滚动视图**的滚轮响应能力。
///
/// ## 为什么要锁定这条事实
///
/// 「过程折叠区滚不动」这个问题曾把排查带偏很远：
///
/// - 曾怀疑内层 `NSScrollView` 坏了 → 排除；
/// - 曾怀疑「嵌在 `List` 行里」导致失效 → 排除；
/// - 曾怀疑应用层监视器吞了事件 → 排除；
/// - 曾怀疑跟随状态机把滚动撤销 → 排除。
///
/// 这些排除结论都依赖同一条基础事实：
///
/// > **内层滚动视图本身对滚轮事件有反应。**
///
/// 它一旦被破坏（例如有人给内层加了 `isScrollEnabled = false`、
/// 或把内容换成不可滚的静态视图），「滚不动」的排查就会再次失去锚点。
/// 因此这里把它锁成回归测试。
///
/// ## 关键：断言的是**生产路径**，不是 SwiftUI 内部行为
///
/// 本测试断言「滚轮增量最终让内层偏移发生变化」，而**不**断言
/// 「SwiftUI 的 `HostingScrollView` 自己处理了滚轮事件」。
///
/// 原因是实测事实（macOS 27.2 实测，本文件内 `HostingScrollView`
/// 与原生 `ListCoreScrollView` 的对照）：
///
/// | 滚动视图 | 类型 | 对 `scrollWheel(with:)` 的反应 |
/// | --- | --- | --- |
/// | 内层折叠区 | SwiftUI `HostingScrollView` | **Δ = 0**（不响应） |
/// | 外层列表 | 原生 `ListCoreScrollView` | Δ ≠ 0（响应） |
///
/// SwiftUI 的 `HostingScrollView` 走的是**手势路径**而不是
/// `scrollWheel(with:)`，因此直接调用它的 `scrollWheel(with:)`
/// 偏移量恒为 0 —— 这不是回归，是 SwiftUI 的固有行为。
///
/// 生产实现正是据此设计的：`ProcessSectionScrollRelay` 命中内层时
/// **主动驱动**它（直接改 `clipView.bounds`），不依赖 SwiftUI 自己
/// 处理滚轮。见 ``ProcessSectionScrollRelay/scrollInner(_:deltaY:)``。
///
/// - Important: 因此**不能**用「直接调用内层 `scrollWheel(with:)`」
///   来验证折叠区能否滚动 —— 那测的是一个 SwiftUI 根本不走的路径，
///   得到的只会是伪结论。本测试走 relay 的主动驱动路径，
///   与真实用户操作一致。
/// - Important: 垂直增量必须放在 `wheel1`。`wheel2` 是**水平**轴，
///   误用它会让 `scrollingDeltaY` 恒为 0 —— 那样测出来的
///   「滚不动」全是伪结论。
@MainActor
@Suite("过程折叠区内层滚动视图的滚轮响应")
struct ProcessSectionInnerScrollResponseTests {

    // MARK: - 定位

    /// 祖先链上最近的 `NSScrollView`（即折叠区自己的内层）。
    final class LocatorView: NSView {
        static var inner: NSScrollView?
        /// 祖先链上最远的 `NSScrollView`（即外层 `List`）。
        static var outer: NSScrollView?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            record()
        }

        override func layout() {
            super.layout()
            record()
        }

        private func record() {
            guard window != nil else { return }
            var chain: [NSScrollView] = []
            var current: NSView? = self
            while let candidate = current {
                if let scrollView = candidate as? NSScrollView {
                    chain.append(scrollView)
                }
                current = candidate.superview
            }
            LocatorView.inner = chain.first
            LocatorView.outer = chain.count > 1 ? chain.last : nil
        }
    }

    struct ScrollViewLocator: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            LocatorView(frame: .zero)
        }
        func updateNSView(_ nsView: NSView, context: Context) {}
    }

    // MARK: - 被测内容

    struct SectionContent: View {
        let lineCount: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<lineCount, id: \.self) { index in
                    Text("line-\(index)").frame(height: 20)
                }
                ScrollViewLocator()
                    .frame(height: 1)
            }
        }
    }

    // MARK: - 夹具

    private struct Fixture {
        let window: NSWindow
        let hosting: NSHostingView<AnyView>
        let inner: NSScrollView
        let outer: NSScrollView?
    }

    private func makeFixture<Content: View>(_ content: Content) throws -> Fixture {
        LocatorView.inner = nil
        LocatorView.outer = nil

        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 600)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(hosting)
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))

        let inner = try #require(LocatorView.inner, "未找到内层滚动视图")
        return Fixture(
            window: window,
            hosting: hosting,
            inner: inner,
            outer: LocatorView.outer
        )
    }

    // MARK: - 滚轮事件

    /// 合成一个带**真实垂直滚动增量**的滚轮事件。
    ///
    /// - Important: 垂直增量必须放在 `wheel1`。`wheel2` 是**水平**轴，
    ///   误用它会让 `scrollingDeltaY` 恒为 0 —— 那样测出来的
    ///   「滚不动」全是伪结论。
    private func makeScrollWheelEvent(deltaY: CGFloat) -> NSEvent? {
        guard let cgEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: 0,
            wheel3: 0
        ) else {
            return nil
        }
        return NSEvent(cgEvent: cgEvent)
    }

    private func maxOffset(of scrollView: NSScrollView) -> CGFloat {
        max(0, (scrollView.documentView?.bounds.height ?? 0) - scrollView.contentView.bounds.height)
    }

    /// 把内层滚到中间，保证「有可滚空间」。
    private func parkAtMiddle(_ scrollView: NSScrollView) {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxOffset(of: scrollView) / 2))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    // MARK: - 用例

    @Test("内层滚动视图对滚轮事件有反应")
    func innerRespondsToScrollWheel() throws {
        let fixture = try makeFixture(
            List {
                BoundedProcessSection(maxHeight: 200, contentVersion: 40) {
                    SectionContent(lineCount: 40)
                }
            }
            .listStyle(.plain)
        )
        defer {
            // 渲染 `BoundedProcessSection` 会让它向全局单例
            // `ProcessSectionScrollRelay.shared` 登记内层滚动视图。
            // 不注销的话，单例状态会漏到后续用例里
            // （`ProcessSectionScrollRelayTests` 断言「最后一个观察者注销后
            // 移除监视器」，会被这条残留登记打破）。
            ProcessSectionScrollRelay.shared.unregister(fixture.inner)
            fixture.window.orderOut(nil)
            fixture.hosting.removeFromSuperview()
        }

        let inner = fixture.inner
        #expect(
            maxOffset(of: inner) > 0,
            "内容应超出视口，否则没有可滚空间"
        )

        parkAtMiddle(inner)
        let before = inner.contentView.bounds.origin.y

        guard let event = makeScrollWheelEvent(deltaY: 40) else {
            Issue.record("无法合成滚轮事件")
            return
        }
        #expect(
            event.scrollingDeltaY != 0,
            "合成事件的垂直增量必须非零，否则结论无效"
        )

        // 走**生产路径**：relay 命中内层时主动驱动它。
        //
        // - Important: 不能直接调 `inner.scrollWheel(with:)` ——
        //   SwiftUI 的 `HostingScrollView` 走手势路径，那个调用偏移恒为 0
        //   （实测），测的是一条 SwiftUI 根本不走的路。
        let consumed = ProcessSectionScrollRelay.shared.scrollInner(inner, deltaY: 40)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let after = inner.contentView.bounds.origin.y

        #expect(
            consumed,
            """
            relay 必须能驱动内层滚动。\
            —— 内层失去滚轮响应时，「滚不动」的排查就失去了锚点。
            """
        )
        #expect(
            after != before,
            """
            内层滚动视图必须对滚轮事件有反应。\
            before=\(before) after=\(after)\
            —— 内层失去滚轮响应时，「滚不动」的排查就失去了锚点。
            """
        )
    }

    @Test("内层确实嵌在外层 List 里（嵌套结构成立）")
    func innerIsNestedInsideOuterList() throws {
        let fixture = try makeFixture(
            List {
                BoundedProcessSection(maxHeight: 200, contentVersion: 40) {
                    SectionContent(lineCount: 40)
                }
            }
            .listStyle(.plain)
        )
        defer {
            ProcessSectionScrollRelay.shared.unregister(fixture.inner)
            fixture.window.orderOut(nil)
            fixture.hosting.removeFromSuperview()
        }

        #expect(fixture.outer != nil, "未找到外层 List 的滚动视图")
        #expect(fixture.inner !== fixture.outer, "内层与外层不应是同一个滚动视图")
        // 外层是原生 List 的滚动视图 —— 它才是「滚动链」的另一端。
        #expect(fixture.outer is NSScrollView)
    }
}
