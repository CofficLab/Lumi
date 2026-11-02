import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区的**限高 frame**必须带 `minHeight`。
///
/// ## 为什么这是回归测试
///
/// 折叠区曾经「拖右侧滚动条能滚、滚轮不能滚」。根因是：
///
/// `BoundedProcessSection` 只用 `.frame(maxHeight:)` 限定 `ScrollView` 高度。
/// `ScrollView` 的固有高度等于**内容高度**（实测 3576pt），`List` 把这一行
/// 裁到上限（160pt）时，SwiftUI 会把内层 clipView 的可视高度一并压成 **0** ——
///
/// - 内层于是**没有可视区域**，滚轮与拖拽都无处可滚；
/// - 而拖动滚动条直接操作 scroller 的几何、不依赖可视区域，所以仍能拖动。
///
/// 真实 app 的实测读数（DEBUG 几何探针）：
///
/// | 写法 | document | visible（clipView 可视高度） |
/// | --- | --- | --- |
/// | `.frame(maxHeight:)` | 3576 | **0** |
/// | `.frame(height:)` | 3576 | 160 |
/// | `.frame(minHeight: 1, maxHeight:)` | 3576 | **160** |
///
/// `minHeight` 给 SwiftUI 一个确定的下界，clipView 就不再塌成 0；
/// `minHeight: 1`（而不是 `maxHeight`）保留了「内容短于上限时自适应」的语义。
///
/// - Important: 本测试在**真实 `List` 行**里渲染生产组件，量的是
///   **内层 clipView 的可视高度** —— 不是行的总高度。行的总高度在两种写法下
///   都是 160（上限），只有 clipView 的可视高度能区分「能不能滚」。
@MainActor
@Suite("过程折叠区限高 frame 的 minHeight 约束")
struct ProcessSectionMinHeightTests {

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

    /// 内层 clipView 的可视高度。
    private func visibleHeight(of scrollView: NSScrollView) -> CGFloat {
        scrollView.contentView.bounds.height
    }

    /// 内容的文档高度。
    private func documentHeight(of scrollView: NSScrollView) -> CGFloat {
        scrollView.documentView?.bounds.height ?? 0
    }

    // MARK: - 用例

    @Test("内容超限时：内层有非零可视高度，且内容完整未被裁剪")
    func overflowingContentKeepsNonZeroViewport() throws {
        let maxHeight: CGFloat = 160

        let fixture = try makeFixture(
            List {
                BoundedProcessSection(maxHeight: maxHeight, contentVersion: 40) {
                    SectionContent(lineCount: 40)
                }
            }
            .listStyle(.plain)
        )
        defer {
            // 渲染 `BoundedProcessSection` 会让它向全局单例
            // `ProcessSectionScrollRelay.shared` 登记内层滚动视图。
            // 不注销的话，单例状态会漏到后续用例里。
            ProcessSectionScrollRelay.shared.unregister(fixture.inner)
            fixture.window.orderOut(nil)
            fixture.hosting.removeFromSuperview()
        }

        let visible = visibleHeight(of: fixture.inner)
        let document = documentHeight(of: fixture.inner)

        #expect(
            visible > 0,
            """
            内层 clipView 的可视高度必须大于 0。\
            实际=\(visible)\
            —— 高度为 0 时滚轮无处可滚，表现为「拖滚动条能滚、滚轮不能滚」。
            """
        )

        #expect(
            document > maxHeight,
            """
            内容应超出上限（否则测不到滚动模式）。\
            document=\(document) maxHeight=\(maxHeight)
            """
        )
    }

    @Test("内容短于上限时：高度自适应，不占满上限")
    func shortContentStaysAdaptive() throws {
        let maxHeight: CGFloat = 400

        let fixture = try makeFixture(
            List {
                BoundedProcessSection(maxHeight: maxHeight, contentVersion: 3) {
                    SectionContent(lineCount: 3)
                }
            }
            .listStyle(.plain)
        )
        defer {
            // 渲染 `BoundedProcessSection` 会让它向全局单例
            // `ProcessSectionScrollRelay.shared` 登记内层滚动视图。
            // 不注销的话，单例状态会漏到后续用例里。
            ProcessSectionScrollRelay.shared.unregister(fixture.inner)
            fixture.window.orderOut(nil)
            fixture.hosting.removeFromSuperview()
        }

        let visible = visibleHeight(of: fixture.inner)
        let document = documentHeight(of: fixture.inner)

        #expect(
            visible > 0,
            "内层 clipView 的可视高度必须大于 0，实际=\(visible)"
        )

        #expect(
            visible < maxHeight,
            """
            内容短于上限时高度应自适应（不占满上限）。\
            visible=\(visible) maxHeight=\(maxHeight) document=\(document)
            """
        )
    }
}
