import LumiUI
import SwiftUI

/// 近 30 天 token 消耗的轻量曲线。
///
/// 与 `AppLineChart` 的分工：后者是设置面板里的统计图，自带卡片底、网格线、
/// 坐标轴日期与悬停提示；空态里只需要一句「最近更活跃了」的形状暗示，
/// 刻度在这里没有可读的坐标轴，反而会把整块拉回「设置页图表」的语言。
/// 因此这里只画线、面积渐变与末点，不画任何网格与刻度。
///
/// - Important: 曲线的颜色与热力图共用 `theme.primary` 的同一族色阶，
///   两块图因此读起来是「同一段时间的两种视图」而不是两个控件。
struct ActivitySparkline: View {
    @LumiTheme private var theme
    let values: [Double]
    let accessibilityLabel: String

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                draw(context: &context, size: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    // MARK: - 绘制

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let points = ActivitySparklineGeometry.points(values: values, size: size)
        guard let first = points.first, let last = points.last, points.count > 1 else { return }

        var line = Path()
        line.move(to: first)
        for point in points.dropFirst() {
            line.addLine(to: point)
        }

        // 面积渐变给曲线一个底，让它在卡片里不是一根悬空的线。
        var area = line
        area.addLine(to: CGPoint(x: last.x, y: size.height))
        area.addLine(to: CGPoint(x: first.x, y: size.height))
        area.closeSubpath()
        context.fill(
            area,
            with: .linearGradient(
                Gradient(colors: [theme.primary.opacity(0.22), theme.primary.opacity(0)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        context.stroke(
            line,
            with: .color(theme.primary),
            style: StrokeStyle(
                lineWidth: ActivitySparklineGeometry.lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )

        // 末点加重：它是「最近一天」，也是曲线唯一有方向感的位置。
        let radius = ActivitySparklineGeometry.endPointRadius
        context.fill(
            Path(ellipseIn: CGRect(x: last.x - radius, y: last.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(theme.primary)
        )
    }
}

/// 曲线与画布之间的坐标映射。
///
/// 抽成纯几何，让「点一定落在画布内」「等值序列是一条直线」这类不变量可以被
/// 单测钉住：Canvas 里画错了不会让编译失败，只能靠几何断言守住。
enum ActivitySparklineGeometry {
    /// 曲线线宽。
    static let lineWidth: CGFloat = 2
    /// 末点半径。横向的内缩量取它，是为了让首末两个圆点完整落在画布内。
    static let endPointRadius: CGFloat = 3
    /// 纵向内缩：让最高点不贴着画布顶边。
    static let verticalInset: CGFloat = 4

    /// 把数值序列映射成画布上的点。
    ///
    /// 归一化以窗口内的峰值为基准（而不是固定上限），因此「用得少」和「用得多」
    /// 的用户看到的形状一样清楚，不会出现一条贴底的直线。
    static func points(values: [Double], size: CGSize) -> [CGPoint] {
        guard !values.isEmpty, size.width > 0, size.height > 0 else { return [] }

        let maxValue = max(values.max() ?? 0, 1)
        let usableWidth = max(size.width - endPointRadius * 2, 1)
        let usableHeight = max(size.height - verticalInset * 2, 1)

        return values.enumerated().map { index, value in
            let ratio = values.count == 1 ? 0.5 : CGFloat(index) / CGFloat(values.count - 1)
            return CGPoint(
                x: endPointRadius + usableWidth * ratio,
                y: verticalInset + usableHeight * (1 - CGFloat(value / maxValue))
            )
        }
    }
}

// MARK: - 预览

/// Deterministic token series shaped like a real usage rhythm: a weekly cycle
/// with a heavier day, which is what makes a trend line worth drawing at all.
@MainActor
private enum ActivitySparklinePreview {
    static var values: [Double] {
        (0..<30).map { index in
            let base = index < 16 ? 0.05 : 0.05 + Double(index - 15) * 0.06
            return base + (index == 23 ? 0.28 : 0) + (index == 28 ? 0.12 : 0)
        }
    }
}

#Preview("Activity sparkline") {
    ActivitySparkline(
        values: ActivitySparklinePreview.values,
        accessibilityLabel: "Daily token consumption chart"
    )
    .padding(24)
    .frame(width: 380, height: 56)
    .background(Color(hex: "FAFAF9"))
}
