import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区的**滚轮方向语义**与**主动驱动**。
///
/// ## 为什么需要这一层测试
///
/// 用户报告：「在 V1 的过程区域滚动，触发的是外部的滚动条，
/// 它自己根本不滚动。」
///
/// 根因：SwiftUI 的 `HostingScrollView` 自己的滚轮方向与原生
/// `NSScrollView` **相反**（`offset -= deltaY` vs `offset += deltaY`）。
/// 过程折叠区展开时自动钉在**底部**，用户「向上滑看更早的内容」时，
/// SwiftUI 语义要求 offset **增大** → 已在最大值 → 没有空间 → 内层不动；
/// 事件落到外层原生 List → **外层滚动条动**。
///
/// 修复：`ProcessSectionScrollRelay` 命中内层时**主动驱动**它，
/// 方向用**原生**语义。
///
/// 本文件锁住三件事：
///
/// 1. SwiftUI 内层的方向语义（`offset -= deltaY`）—— 事实基准；
/// 2. relay 主动驱动内层时用的是**原生**语义（`offset += deltaY`）；
/// 3. 贴底时向上滚，内层**确实**能滚（用户场景）。
@MainActor
@Suite("过程折叠区的滚轮方向与主动驱动")
struct ProcessSectionScrollDirectionTests {

    // MARK: - 定位

    /// 祖先链上最近的 `NSScrollView`（折叠区自己的内层）。
    final class LocatorView: NSView {
        static var inner: NSScrollView?

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
            var current: NSView? = self
            while let candidate = current {
                if let scrollView = candidate as? NSScrollView {
                    LocatorView.inner = scrollView
                    break
                }
                current = candidate.superview
            }
        }
    }

    struct ScrollViewLocator: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            LocatorView(frame: .zero)
        }
        func updateNSView(_ nsView: NSView, context: Context) {}
    }

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

    // MARK: - 事件

    /// 合成一个带**真实垂直滚动增量**的滚轮事件。
    ///
    /// - Important: 垂直增量必须放在 `wheel1`。`wheel2` 是**水平**轴，
    ///   误用它会让 `scrollingDeltaY` 恒为 0。
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

    // MARK: - 夹具

    private func makeFixture<Content: View>(_ content: Content) throws -> (window: NSWindow, hosting: NSHostingView<AnyView>, inner: NSScrollView) {
        LocatorView.inner = nil

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
        return (window, hosting, inner)
    }

    private func maxOffset(of scrollView: NSScrollView) -> CGFloat {
        max(0, (scrollView.documentView?.bounds.height ?? 0) - scrollView.contentView.bounds.height)
    }

    private func setOffset(_ scrollView: NSScrollView, _ offset: CGFloat) {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: offset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    // MARK: - 用例

    @Test("事实基准：SwiftUI 内层的方向语义是 offset -= deltaY")
    func swiftUIInnerUsesOppositeDirection() throws {
        let lineCount = 40
        let maxHeight: CGFloat = 160

        let fixture = try makeFixture(
            List {
                BoundedProcessSection(maxHeight: maxHeight, contentVersion: lineCount) {
                    SectionContent(lineCount: lineCount)
                }
            }
        )
        defer {
            ProcessSectionScrollRelay.shared.unregister(fixture.inner)
            fixture.window.orderOut(nil)
            fixture.hosting.removeFromSuperview()
        }

        let inner = fixture.inner
        let maxOffset = maxOffset(of: inner)

        setOffset(inner, maxOffset / 4)
        let before = inner.contentView.bounds.origin.y
        guard let event = makeScrollWheelEvent(deltaY: -40) else {
            Issue.record("无法合成滚轮事件")
            return
        }
        inner.scrollWheel(with: event)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let after = inner.contentView.bounds.origin.y

        #expect(
            after > before,
            """
            SwiftUI 内层的方向语义是 `offset -= deltaY`：\
            `deltaY = -40` 应让 offset **增大**。\
            before=\(before) after=\(after)\
            —— 这是「贴底时向上滚撞边界」的成因，必须锁住。
            """
        )
    }

    @Test("修复：relay 主动驱动内层时用原生语义（offset += deltaY）")
    func relayDrivesInnerWithNativeDirection() throws {
        let lineCount = 40
        let maxHeight: CGFloat = 160

        let fixture = try makeFixture(
            List {
                BoundedProcessSection(maxHeight: maxHeight, contentVersion: lineCount) {
                    SectionContent(lineCount: lineCount)
                }
            }
        )
        defer {
            ProcessSectionScrollRelay.shared.unregister(fixture.inner)
            fixture.window.orderOut(nil)
            fixture.hosting.removeFromSuperview()
        }

        let inner = fixture.inner
        let maxOffset = maxOffset(of: inner)

        // 贴底（用户展开折叠区后的实际状态）。
        setOffset(inner, maxOffset)
        let before = inner.contentView.bounds.origin.y

        // relay 主动驱动内层（原生语义：deltaY < 0 → offset 减小）。
        let consumed = ProcessSectionScrollRelay.shared.scrollInner(inner, deltaY: -40)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        let after = inner.contentView.bounds.origin.y
        #expect(
            consumed,
            "relay 应当能驱动内层滚动（贴底时向上滚有空间可走）"
        )
        #expect(
            after < before,
            """
            原生语义下向上滚（deltaY < 0）应让 offset 减小。\
            before=\(before) after=\(after)
            """
        )
    }

    @Test("用户场景：贴底时向上滚，内层确实能滚")
    func scrollingUpFromBottomMovesInnerOffset() throws {
        let lineCount = 40
        let maxHeight: CGFloat = 160

        let fixture = try makeFixture(
            List {
                BoundedProcessSection(maxHeight: maxHeight, contentVersion: lineCount) {
                    SectionContent(lineCount: lineCount)
                }
            }
        )
        defer {
            ProcessSectionScrollRelay.shared.unregister(fixture.inner)
            fixture.window.orderOut(nil)
            fixture.hosting.removeFromSuperview()
        }

        let inner = fixture.inner
        let maxOffset = maxOffset(of: inner)

        // 前置条件：内层贴底（展开折叠区后的实际状态）。
        setOffset(inner, maxOffset)
        let before = inner.contentView.bounds.origin.y
        #expect(
            abs(before - maxOffset) <= 1,
            """
            前置条件：内层应贴底。offset=\(before) maxOffset=\(maxOffset)
            """
        )

        // 走 relay 的主动驱动：贴底时向上滚应让内层滚起来。
        let consumed = ProcessSectionScrollRelay.shared.scrollInner(inner, deltaY: -40)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        let after = inner.contentView.bounds.origin.y
        #expect(
            consumed,
            "relay 应当能驱动内层滚动"
        )
        #expect(
            after < before,
            """
            贴底时向上滚，内层必须能滚（用户报告的场景）。\
            before=\(before) after=\(after)
            """
        )
    }
}
