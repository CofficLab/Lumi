import SwiftUI

// MARK: - Flip Book View

/// 「装订后」示意图：一本可交互的虚拟小册子。
/// 点击左右两侧或水平拖动即可翻页，带 3D 翻页动画。
struct FlipBookView: View {
    let document: CurrentPDFDocument

    /// 一个 spread 的左右槽位（nil 表示该侧无页面）
    private typealias Spread = (left: Int?, right: Int?)

    /// 书本的展开方式：封面在右半侧、封底在左半侧，中间为左右对页。
    /// 8 页 → (-,1) (2,3) (4,5) (6,7) (8,-)
    private var spreads: [Spread] {
        guard document.pageCount > 0 else { return [] }
        var result: [Spread] = [(nil, 1)]
        var page = 2
        while page <= document.pageCount {
            result.append((page, page < document.pageCount ? page + 1 : nil))
            page += 2
        }
        return result
    }

    /// 当前展开的 spread 下标
    @State private var spreadIndex = 0

    /// 拖拽中的翻页进度（0…1）
    @State private var flipProgress: CGFloat = 0

    /// 翻页方向：true = 向前翻（右页翻到左边），false = 向后翻
    @State private var flippingForward = true

    var body: some View {
        GeometryReader { geo in
            let pageHeight = min(
                geo.size.height - 30,
                geo.size.width / max(document.pageAspectRatio * 2, 0.01)
            )
            let pageWidth = pageHeight * document.pageAspectRatio

            VStack(spacing: 8) {
                ZStack {
                    // 静止纸页：拖动时只替换被翻页下方的那一侧。
                    // 翻动纸张的背面由 flippingPage 渲染，不能提前作为
                    // 目标 spread 的另一半露出来。
                    if !spreads.isEmpty {
                        spreadView(
                            isFlipping ? stationarySpreadDuringFlip : spreads[spreadIndex],
                            pageWidth: pageWidth,
                            pageHeight: pageHeight
                        )

                        // 顶层：正在翻转的那一页
                        if isFlipping {
                            flippingPage(pageWidth: pageWidth, pageHeight: pageHeight)
                        }

                        // 左右点击热区
                        HStack(spacing: 0) {
                            Color.clear.contentShape(Rectangle())
                                .onTapGesture { flipBackward() }
                            Color.clear.contentShape(Rectangle())
                                .onTapGesture { flipForward() }
                        }
                        .frame(width: pageWidth * 2, height: pageHeight)
                    }
                }
                .frame(width: pageWidth * 2, height: pageHeight)
                .contentShape(Rectangle())
                .gesture(flipDrag(pageWidth: pageWidth))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: document.id) { _, _ in
            spreadIndex = 0
            flipProgress = 0
        }
    }

    // MARK: - Spread Rendering

    private var isFlipping: Bool { flipProgress > 0 }

    /// 翻页时底层应显示的 spread
    private var targetSpreadIndex: Int {
        guard isFlipping else { return spreadIndex }
        return flippingForward
            ? min(spreadIndex + 1, spreads.count - 1)
            : max(spreadIndex - 1, 0)
    }

    /// 翻页过程中留在书面上的两页。
    ///
    /// 向前翻时，当前右页是翻动纸张的正面、目标左页是它的背面，
    /// 所以静止层只能显示“当前左页 + 目标右页”。向后翻则相反。
    private var stationarySpreadDuringFlip: Spread {
        let current = spreads[spreadIndex]
        let target = spreads[targetSpreadIndex]
        return flippingForward
            ? (current.left, target.right)
            : (target.left, current.right)
    }

    /// 渲染一个完整 spread（空槽位用透明占位）
    private func spreadView(_ spread: Spread,
                            pageWidth: CGFloat,
                            pageHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            pageSlot(spread.left, pageWidth: pageWidth, pageHeight: pageHeight)
            pageSlot(spread.right, pageWidth: pageWidth, pageHeight: pageHeight)
        }
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func pageSlot(_ page: Int?, pageWidth: CGFloat, pageHeight: CGFloat) -> some View {
        if let page {
            PDFDocumentPageView(documentURL: document.url, pageNumber: page)
                .frame(width: pageWidth, height: pageHeight)
        } else {
            Color.clear.frame(width: pageWidth, height: pageHeight)
        }
    }

    /// 正在翻转的页面：正面为当前页，转过 90° 后显示相邻页（镜像）
    @ViewBuilder
    private func flippingPage(pageWidth: CGFloat, pageHeight: CGFloat) -> some View {
        // 向前翻：右页绕书脊 0 → -180，落在左侧
        // 向后翻：左页绕书脊 0 → +180，落在右侧
        let angle = flippingForward
            ? -180 * flipProgress
            : 180 * flipProgress

        let current = spreads[spreadIndex]
        let target = spreads[targetSpreadIndex]

        let frontPage = flippingForward ? current.right : current.left
        let backPage = flippingForward ? target.left : target.right

        let showBack = abs(angle) > 90

        ZStack {
            if showBack, let backPage {
                PDFDocumentPageView(documentURL: document.url, pageNumber: backPage)
                    .frame(width: pageWidth, height: pageHeight)
                    .scaleEffect(x: -1, y: 1)  // 镜像，让背面内容方向正确
            } else if let frontPage {
                PDFDocumentPageView(documentURL: document.url, pageNumber: frontPage)
                    .frame(width: pageWidth, height: pageHeight)
            }
        }
        .frame(width: pageWidth, height: pageHeight)
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            anchor: flippingForward ? .leading : .trailing,
            perspective: 0.4
        )
        // 向前翻：页面位于右半，绕左边缘（书脊）旋转
        // 向后翻：页面位于左半，绕右边缘（书脊）旋转
        .offset(x: flippingForward ? pageWidth / 2 : -pageWidth / 2)
        .zIndex(1)
    }

    // MARK: - Interaction

    private var canFlipForward: Bool { spreadIndex < spreads.count - 1 }
    private var canFlipBackward: Bool { spreadIndex > 0 }

    private func flipForward() {
        guard canFlipForward, !isFlipping else { return }
        flippingForward = true
        withAnimation(.easeInOut(duration: 0.45)) {
            flipProgress = 1
        }
        completeFlip(after: 0.45)
    }

    private func flipBackward() {
        guard canFlipBackward, !isFlipping else { return }
        flippingForward = false
        withAnimation(.easeInOut(duration: 0.45)) {
            flipProgress = 1
        }
        completeFlip(after: 0.45)
    }

    /// 动画结束后落位到目标 spread 并复位进度
    private func completeFlip(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            spreadIndex = flippingForward
                ? min(spreadIndex + 1, spreads.count - 1)
                : max(spreadIndex - 1, 0)
            flipProgress = 0
        }
    }

    private func flipDrag(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let dx = value.translation.width
                if dx < 0, canFlipForward {
                    flippingForward = true
                    flipProgress = min(1, -dx / pageWidth)
                } else if dx > 0, canFlipBackward {
                    flippingForward = false
                    flipProgress = min(1, dx / pageWidth)
                }
            }
            .onEnded { _ in
                if flipProgress > 0.35 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        flipProgress = 1
                    }
                    completeFlip(after: 0.25)
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        flipProgress = 0
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview("Flip Book") {
    FlipBookView(document: try! DemoPDFProvider.makeDocument())
        .frame(width: 480, height: 300)
        .padding()
}
