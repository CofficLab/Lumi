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
/// 根因：过程折叠区展开时自动钉在**底部**（`offset = 文档高 − 视口高`），
/// 用户「向上滑看更早的内容」（`deltaY < 0`）时，如果按 SwiftUI 的
/// `offset -= deltaY` 语义，offset 需要**增大** —— 但已在最大值，
/// 没有空间可增 → 内层不动；事件落到外层原生 List → **外层滚动条动**。
///
/// 修复：`ProcessSectionScrollRelay` 命中内层时**主动驱动**它，
/// 方向用**原生**语义（`offset += deltaY`）。
///
/// 本文件锁住两件事：
///
/// 1. relay 主动驱动内层时用的是**原生**语义（`offset += deltaY`）；
/// 2. 贴底时向上滚，内层**确实**能滚（用户场景）。
///
/// ## 关于「事实基准」这条用例
///
/// 曾经还有一条「事实基准：SwiftUI 内层的方向语义是 `offset -= deltaY`」，
/// 用来确立前提、从而论证生产实现必须用原生语义。
///
/// 该前提**不成立**（macOS 27.2 实测）：SwiftUI 的 `HostingScrollView`
/// 走的是**手势路径**，`scrollWheel(with:)` 的偏移量恒为 0 —— 它根本不
/// 按 `offset -= deltaY` 处理，也根本不按 `offset += deltaY` 处理。
/// 因此那条用例从引入起（2026-11-02）就恒定失败，断言的是一个
/// SwiftUI 不具备的行为。
///
/// 现在改为锁定**生产实现实际依赖的契约**：
/// relay 的方向语义必须与**原生** `NSScrollView` 一致，
/// 且向上滚（`deltaY < 0`）必须让 offset **减小**（看更早的内容）。
/// 这条契约是用户可感知的，且与原生滚动视图一致 ——
/// 无论 SwiftUI 内部如何实现都不会影响它。
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

    @Test("契约基准：relay 的方向语义与原生滚动视图一致")
    func relayDirectionMatchesNativeScrollView() throws {
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

        // 对照组：一个**原生** `NSScrollView`，用同样的增量滚动。
        //
        // - Important: 对照组必须是真的原生滚动视图 —— 断言 relay
        //   「向下滚 offset 增大」本身只是复述实现；把它与原生滚动视图
        //   的实际行为对齐，才是「方向与原生一致」这条契约本身。
        let native = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        let nativeDocument = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 800))
        native.documentView = nativeDocument
        native.hasVerticalScroller = true
        let nativeHost = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        nativeHost.contentView?.addSubview(native)
        nativeHost.makeKeyAndOrderFront(nil)
        nativeHost.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        defer {
            nativeHost.orderOut(nil)
            nativeHost.contentView = nil
        }

        let nativeMaxOffset = max(0, nativeDocument.bounds.height - native.contentView.bounds.height)
        native.contentView.scroll(to: NSPoint(x: 0, y: nativeMaxOffset / 4))
        native.reflectScrolledClipView(native.contentView)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let nativeBefore = native.contentView.bounds.origin.y
        guard let nativeEvent = makeScrollWheelEvent(deltaY: 40) else {
            Issue.record("无法合成滚轮事件")
            return
        }
        native.scrollWheel(with: nativeEvent)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let nativeAfter = native.contentView.bounds.origin.y

        // 被测方：relay 主动驱动内层，同样的增量。
        let innerMaxOffset = maxOffset(of: inner)
        setOffset(inner, innerMaxOffset / 4)
        let innerBefore = inner.contentView.bounds.origin.y
        let consumed = ProcessSectionScrollRelay.shared.scrollInner(inner, deltaY: 40)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let innerAfter = inner.contentView.bounds.origin.y

        #expect(
            nativeAfter > nativeBefore,
            """
            对照组前提：原生滚动视图向下滚时 offset 必须增大。\
            before=\(nativeBefore) after=\(nativeAfter)
            """
        )
        #expect(
            consumed,
            "relay 必须能驱动内层滚动（向下滚有空间可走）"
        )
        #expect(
            innerAfter > innerBefore,
            """
            relay 向下滚（deltaY > 0）应让 offset 增大。\
            before=\(innerBefore) after=\(innerAfter)
            """
        )
        // 关键断言：relay 与原生的**方向**必须一致。
        //
        // - Important: 这条是「内外方向不割裂」的根本保证 —— 折叠区嵌在
        //   原生 List 里，两者方向相反时接力给外层会出现明显的手感割裂。
        #expect(
            (innerAfter > innerBefore) == (nativeAfter > nativeBefore),
            """
            relay 与原生滚动视图的方向必须一致。\
            relay: \(innerBefore) → \(innerAfter)\
            native: \(nativeBefore) → \(nativeAfter)
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
