import SwiftUI

// MARK: - Flip Book View

/// 「装订后」示意图：一本可交互的虚拟小册子。
/// 点击左右两侧或水平拖动即可翻页，带 3D 翻页动画。
struct FlipBookView: View {

    /// 一个 spread 的左右槽位（nil 表示该侧无页面）
    private typealias Spread = (left: Int?, right: Int?)

    /// 书本的展开方式：封面在右半侧、封底在左半侧，中间为左右对页。
    /// 8 页 → (-,1) (2,3) (4,5) (6,7) (8,-)
    private var spreads: [Spread] {
        var result: [Spread] = [(nil, 1)]
        var page = 2
        while page <= SampleStory.pageCount - 1 {
            result.append((page, page + 1))
            page += 2
        }
        result.append((SampleStory.pageCount, nil))
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
            let pageHeight = min(geo.size.height - 30, geo.size.width * 1.414 / 2)
            let pageWidth = pageHeight / 1.414

            VStack(spacing: 8) {
                ZStack {
                    // 底层：翻页目标 spread
                    spreadView(spreads[targetSpreadIndex],
                               pageWidth: pageWidth,
                               pageHeight: pageHeight,
                               dimmed: isFlipping)

                    // 中层：当前 spread 中不参与翻页的一半
                    if !isFlipping {
                        spreadView(spreads[spreadIndex],
                                   pageWidth: pageWidth,
                                   pageHeight: pageHeight)
                    } else if flippingForward, let left = spreads[spreadIndex].left {
                        halfPage(left, atLeft: true, pageWidth: pageWidth, pageHeight: pageHeight)
                    } else if !flippingForward, let right = spreads[spreadIndex].right {
                        halfPage(right, atLeft: false, pageWidth: pageWidth, pageHeight: pageHeight)
                    }

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
                .frame(width: pageWidth * 2, height: pageHeight)
                .contentShape(Rectangle())
                .gesture(flipDrag(pageWidth: pageWidth))
            }
            .frame(width: geo.size.width, height: geo.size.height)
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

    /// 渲染一个完整 spread（空槽位用透明占位）
    private func spreadView(_ spread: Spread,
                            pageWidth: CGFloat,
                            pageHeight: CGFloat,
                            dimmed: Bool = false) -> some View {
        HStack(spacing: 0) {
            pageSlot(spread.left, pageWidth: pageWidth, pageHeight: pageHeight)
            pageSlot(spread.right, pageWidth: pageWidth, pageHeight: pageHeight)
        }
        .opacity(dimmed ? 0.9 : 1)
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func pageSlot(_ page: Int?, pageWidth: CGFloat, pageHeight: CGFloat) -> some View {
        if let page {
            StoryPageView(pageNumber: page, height: pageHeight, textScale: 1.2)
        } else {
            Color.clear.frame(width: pageWidth, height: pageHeight)
        }
    }

    /// 单独渲染半页（翻页时保留在原地的那一半）
    private func halfPage(_ page: Int, atLeft: Bool,
                          pageWidth: CGFloat, pageHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            if atLeft {
                StoryPageView(pageNumber: page, height: pageHeight, textScale: 1.2)
                Color.clear.frame(width: pageWidth, height: pageHeight)
            } else {
                Color.clear.frame(width: pageWidth, height: pageHeight)
                StoryPageView(pageNumber: page, height: pageHeight, textScale: 1.2)
            }
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
                StoryPageView(pageNumber: backPage, height: pageHeight, textScale: 1.2)
                    .scaleEffect(x: -1, y: 1)  // 镜像，让背面内容方向正确
            } else if let frontPage {
                StoryPageView(pageNumber: frontPage, height: pageHeight, textScale: 1.2)
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
    FlipBookView()
        .frame(width: 480, height: 300)
        .padding()
}
