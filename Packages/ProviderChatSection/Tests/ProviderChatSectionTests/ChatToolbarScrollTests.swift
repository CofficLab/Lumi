import AppKit
import LumiUI
import SwiftUI
import Testing
@testable import ProviderChatSection

/// 聊天工具栏横向滚动回归测试。
///
/// 插件通过 `ChatSectionBarItem(placement: .toolbarLeading/.toolbarTrailing)`
/// 注入的 UI 数量不可控，窄窗口下内容总宽度可能超出工具栏可用宽度。
///
/// 改造前工具栏用固定 `HStack` 承载贡献项：宽度不足时 SwiftUI 会压缩
/// 可压缩的内容（如带 `lineLimit(1)` 的 `Text`），表现为按钮文字被截断、
/// 插件注入的 UI 被挤扁且无法查看。
///
/// 改造后工具栏用横向 `ScrollView` 承载贡献项：贡献项保持自身自然宽度，
/// 超出部分通过横向滚动查看。这里锁定「贡献项不被压缩」这一契约。
@MainActor
@Suite("Chat Toolbar Scrolling Tests")
struct ChatToolbarScrollTests {

    // MARK: - Helpers

    /// 记录某个视图实际被分配到的宽度与在工具栏内的垂直位置。
    ///
    /// 用 `GeometryReader` 读取真实布局结果，而不是靠像素猜测。
    final class LayoutProbe: @unchecked Sendable {
        private(set) var width: CGFloat = 0
        private(set) var minY: CGFloat = 0
        private(set) var height: CGFloat = 0

        func set(width: CGFloat, minY: CGFloat, height: CGFloat) {
            self.width = width
            self.minY = minY
            self.height = height
        }

        /// 贡献项在工具栏坐标系里的垂直中心。
        var centerY: CGFloat { minY + height / 2 }
    }

    /// 探针所在的命名坐标系，用于把贡献项的位置换算到工具栏坐标系。
    private static let spaceName = "ChatToolbarRowTestSpace"

    /// 把探针装在内容后面，读出内容实际拿到的宽度与垂直位置。
    private struct ProbeBackground: View {
        let probe: LayoutProbe

        var body: some View {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { update(proxy: proxy) }
                    .onChange(of: proxy.size.width) { _, _ in update(proxy: proxy) }
            }
        }

        private func update(proxy: GeometryProxy) {
            let frame = proxy.frame(in: .named(ChatToolbarScrollTests.spaceName))
            probe.set(width: proxy.size.width, minY: frame.minY, height: frame.height)
        }
    }

    /// 构造一个「可压缩」的贡献项：文字越长，理想宽度越大。
    private func makeFlexibleItem(id: String, text: String, probe: LayoutProbe) -> ChatSectionBarItem {
        ChatSectionBarItem(id: id, placement: .toolbarTrailing) {
            Text(text)
                .font(.system(size: 12))
                .lineLimit(1)
                .background(ProbeBackground(probe: probe))
        }
    }

    /// 把视图放进 `NSHostingView` 并强制布局，等待探针上报尺寸。
    private func layout<V: View>(
        _ view: V,
        containerWidth: CGFloat
    ) {
        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = NSRect(x: 0, y: 0, width: containerWidth, height: 28)
        hosting.layoutSubtreeIfNeeded()
        // `NSHostingView` 的布局在下一轮 runloop 才完全落定，
        // 这里显式跑一次 runloop 以确保 `GeometryReader` 已经上报尺寸。
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        hosting.layoutSubtreeIfNeeded()
    }

    /// 工具栏栏体高度（`AppPanelBar` 固定高度）。
    private var barHeight: CGFloat { AppPanelChromeMetrics.breadcrumbBarHeight }

    // MARK: - Tests

    @Test("宽度富余时工具栏内容按自然宽度左对齐，不被拉伸也不被压缩")
    func toolbarKeepsNaturalWidthWhenSpaceIsEnough() {
        let probe = LayoutProbe()
        let items = [
            makeFlexibleItem(id: "a", text: "Short", probe: probe)
        ]
        let row = ChatToolbarRow(items: items)
            .coordinateSpace(name: Self.spaceName)

        layout(row, containerWidth: 600)

        #expect(probe.width > 0, "工具栏贡献项未获得任何宽度")
        #expect(probe.width < 600, "贡献项不应被拉伸到容器宽度")
    }

    @Test("宽度不足时贡献项保持自然宽度，而不是被压缩成容器宽度")
    func toolbarDoesNotCompressItemsWhenSpaceIsTight() {
        let longText = "A-very-long-plugin-contributed-toolbar-item"
        let wideProbe = LayoutProbe()
        let tightProbe = LayoutProbe()

        // 先测出贡献项的理想宽度。
        layout(
            ChatToolbarRow(items: [makeFlexibleItem(id: "a", text: longText, probe: wideProbe)])
                .coordinateSpace(name: Self.spaceName),
            containerWidth: 800
        )
        #expect(wideProbe.width > 120, "测试前提失败：贡献项理想宽度 \(wideProbe.width) 未超过窄容器宽度")

        // 再在窄容器下测量，贡献项仍应保持该理想宽度。
        layout(
            ChatToolbarRow(items: [makeFlexibleItem(id: "a", text: longText, probe: tightProbe)])
                .coordinateSpace(name: Self.spaceName),
            containerWidth: 120
        )

        #expect(
            tightProbe.width >= wideProbe.width - 1,
            "窄容器下贡献项被压缩到 \(tightProbe.width)，理想宽度为 \(wideProbe.width)"
        )
    }

    @Test("多个贡献项在窄容器下都保持自然宽度")
    func multipleItemsKeepNaturalWidthWhenSpaceIsTight() {
        let probes = (0..<3).map { _ in LayoutProbe() }
        let items = probes.enumerated().map { index, probe in
            makeFlexibleItem(id: "item-\(index)", text: "PluginItem\(index)-with-long-label", probe: probe)
        }

        layout(
            ChatToolbarRow(items: items).coordinateSpace(name: Self.spaceName),
            containerWidth: 120
        )

        for (index, probe) in probes.enumerated() {
            #expect(
                probe.width > 120,
                "第 \(index) 个贡献项被压缩到 \(probe.width)，窄容器不应压缩贡献项"
            )
        }
    }

    @Test("贡献项在工具栏内保持垂直居中")
    func itemsStayVerticallyCentered() {
        let probe = LayoutProbe()
        let items = [
            makeFlexibleItem(id: "a", text: "Short", probe: probe)
        ]

        layout(
            ChatToolbarRow(items: items).coordinateSpace(name: Self.spaceName),
            containerWidth: 400
        )

        // 工具栏内容区（去掉上下各 4pt 内边距）的垂直中点。
        let contentHeight = barHeight - AppPanelChromeMetrics.breadcrumbVerticalPadding * 2
        let expectedCenter = AppPanelChromeMetrics.breadcrumbVerticalPadding + contentHeight / 2
        #expect(
            abs(probe.centerY - expectedCenter) < 3,
            "贡献项中心 \(probe.centerY) 偏离栏内中心 \(expectedCenter)"
        )
    }
}
