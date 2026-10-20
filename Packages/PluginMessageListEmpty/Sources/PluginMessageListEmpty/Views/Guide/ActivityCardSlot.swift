import Foundation
import LumiUI
import SwiftUI

/// 活动卡在空态内容流里的位置。
///
/// ## 为什么它必须待在内容流里，而不是底栏
///
/// 卡片早先被注册在 `bottomFixed` 槽位：它因此永远停在窗口最底部，与中间的
/// 提示胶囊之间隔着一大片空白，底栏与内容区之间还压着一条分隔线 —— 无论
/// 卡片本身画得多好，读起来仍然是「另一个面板」。只有让它**紧跟在提示胶囊
/// 下面**，共用同一列、同一条底色，接缝才会真正消失。
///
/// ## 短窗口的取舍
///
/// 卡片现在位于 `ScrollView` 的内容里，窗口很矮时它可能落在首屏之外，需要
/// 滚动才能看到。这是刻意的取舍：卡片是补充信息（历史活跃度），不是必须
/// 立刻可见的主信息；反过来，底栏方案让「融合」彻底失败。
struct ActivityCardSlot: View {
    let model: EmptyStateActivityViewModel

    /// Width the slot last received from its column.
    ///
    /// Needed only to pick between the side-by-side and the stacked layout:
    /// the sparkline is built on a `GeometryReader`, so it happily shrinks to
    /// any width. `ViewThatFits` therefore cannot detect "too narrow" here —
    /// the flexible child always reports that it fits — and an explicit
    /// measurement is what makes the fallback real.
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        ZStack {
            // - Important: 这个 0 高度的透明占位**不可省略**。
            //
            //   `.task` 绑定在视图的生命周期上，而下面的 `if` 在首次渲染时
            //   一定为假（`totalMessages` 还是 `nil`，`hasActivity` 为 false）。
            //   若容器此刻是空的，SwiftUI 不会为该分支建立真实的 view
            //   identity，`.task` 于是**从不执行** —— 加载永远不会开始，
            //   `hasActivity` 永远保持 false，构成死锁。表现为：明明有历史
            //   数据，活动卡却始终不出现。
            //
            //   实测证据：加日志后 `body` 求值多次而 `loadIfNeeded` 零次执行。
            //   一个 0 高度、透明的真实视图让 `.task` 有可挂载的载体。
            Color.clear
                .frame(height: 0)
                .allowsHitTesting(false)

            if model.hasActivity, let range = model.visibleRange {
                ActivityFusionCard(
                    model: model,
                    range: range,
                    placesSideBySide: placesSideBySide
                )
                .frame(maxWidth: ActivityCardLayout.cardMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .background(alignment: .topLeading) { widthReader }
        .task {
            await model.loadIfNeeded()
        }
    }

    /// Reads the width the slot gives the card without contributing any layout
    /// of its own: a background `GeometryReader` takes the size of the view it
    /// is attached to and is invisible to accessibility.
    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { availableWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { _, width in availableWidth = width }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 只有「宽度够」这一件事成立才并排，否则保持上下排布。
    private var placesSideBySide: Bool {
        ActivityCardLayout.usesSideBySideLayout(availableWidth: availableWidth)
    }
}

/// 活动卡的排布判定。
///
/// 抽成纯几何，让「多宽才并排」这条阈值可以被单测钉住：SwiftUI 里没有
/// 稳定可测的横向自适应 API（见 `ActivityCardSlot.availableWidth` 的注释），
/// 所以阈值本身就是需要保护的契约。
enum ActivityCardLayout {
    /// 卡片最大宽度，与提示胶囊流同宽。
    static let cardMaxWidth: CGFloat = ActivityFusionCardMetrics.maxWidth
    /// 卡片左右内边距。
    static let cardHorizontalPadding: CGFloat = ActivityFusionCardMetrics.horizontalPadding
    /// 30 天窗口最多铺满 6 周；`cellSize` 9 + `cellSpacing` 3 时约 72pt。
    static let heatmapWidth: CGFloat = 72
    /// 两块图之间的间距。
    static let contentSpacing: CGFloat = ActivityFusionCardMetrics.contentSpacing
    /// 两块图之间分隔线的宽度。
    static let separatorWidth: CGFloat = 1
    /// 曲线再窄就会把 30 个采样点挤成一团（点直径 6pt，间距不足 10pt 时
    /// 曲线会糊成一条粗线），此时宁可上下排布。
    static let minSparklineWidth: CGFloat = 180

    /// 并排时卡片内部需要的最小宽度。
    static var sideBySideInnerWidth: CGFloat {
        heatmapWidth + contentSpacing * 2 + separatorWidth + minSparklineWidth
    }

    /// 并排所需的最小可用宽度（含卡片左右内边距）。
    static var sideBySideMinWidth: CGFloat {
        cardHorizontalPadding * 2 + sideBySideInnerWidth
    }

    /// 槽位宽度足够时，卡片内部才并排。
    ///
    /// 判定用的是**卡片的内宽**而不是槽位宽度：卡片本身封顶在
    /// `cardMaxWidth`，再宽的窗口也不会让卡片变宽，因此超过封顶宽度之后
    /// 判定结果必须保持不变。
    static func usesSideBySideLayout(availableWidth: CGFloat) -> Bool {
        let cardWidth = min(availableWidth, cardMaxWidth)
        let innerWidth = cardWidth - cardHorizontalPadding * 2
        return innerWidth >= sideBySideInnerWidth
    }
}

// MARK: - 预览

/// Deterministic sample window for previews, shaped like a real user's rhythm:
/// steady on weekdays, quiet at the start of the window and on weekends.
@MainActor
private enum ActivityCardPreview {
    static func sampleModel() -> EmptyStateActivityViewModel {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today

        var counts: [Date: Int] = [:]
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let isWeekend = weekday == 1 || weekday == 7
            counts[day] = isWeekend ? offset % 3 : 2 + (offset * 7) % 11
        }

        return EmptyStateActivityViewModel(
            messages: nil,
            calendar: calendar,
            seededDays: EmptyStateActivityViewModel.makeDays(
                counts: counts,
                startDate: start,
                endDate: today,
                calendar: calendar
            ),
            seededTokenDays: EmptyStateActivityViewModel.makeTokenDays(
                counts: counts,
                startDate: start,
                endDate: today,
                calendar: calendar
            )
        )
    }
}

#Preview("Activity card slot") {
    ActivityCardSlot(model: ActivityCardPreview.sampleModel())
        .padding(24)
        .frame(width: 620)
}

#Preview("Activity card slot — narrow") {
    ActivityCardSlot(model: ActivityCardPreview.sampleModel())
        .padding(24)
        .frame(width: 280)
}

#Preview("Activity card slot — empty history") {
    ActivityCardSlot(
        model: EmptyStateActivityViewModel(
            messages: nil,
            calendar: Calendar(identifier: .gregorian),
            seededDays: []
        )
    )
    .padding(24)
    .frame(width: 620)
}
