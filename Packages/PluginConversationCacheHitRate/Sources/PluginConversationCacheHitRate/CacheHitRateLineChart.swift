import SwiftUI

/// 缓存命中率历史折线图（Canvas 绘制，支持 hover 查看采样点）。
///
/// 同时绘制两条曲线，便于对照：
/// - **单次命中率**（细线）：该次请求的即时表现，会话初期必然偏低；
/// - **累计命中率**（粗线 + 渐变填充）：截至该次的 token 加权累计值，
///   单调平滑，更能反映缓存是否真正生效。
///
/// 纵轴固定 0–100%，不随数据缩放，保证两条线可在同一尺度下诚实对比。
struct CacheHitRateLineChart: View {
    let samples: [CacheHitRateSample]

    @State private var hoveredIndex: Int?

    private static let inset = EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty, size.width > 0, size.height > 0 else { return }

            let geometry = ChartGeometry(size: size, inset: Self.inset)

            // Grid lines
            var grid = Path()
            for step in 0...2 {
                let y = Self.inset.top + geometry.plotHeight * Double(step) / 2
                grid.move(to: CGPoint(x: Self.inset.leading, y: y))
                grid.addLine(to: CGPoint(x: Self.inset.leading + geometry.plotWidth, y: y))
            }
            context.stroke(grid, with: .color(.secondary.opacity(0.16)), lineWidth: 1)

            let perRequestPoints = geometry.points(for: samples, value: \.hitRate)
            let cumulativePoints = geometry.points(for: samples, value: \.cumulativeHitRate)

            // Fill area under the cumulative curve
            var fill = smoothedPath(points: cumulativePoints)
            fill.addLine(to: CGPoint(x: cumulativePoints.last?.x ?? Self.inset.leading, y: Self.inset.top + geometry.plotHeight))
            fill.addLine(to: CGPoint(x: cumulativePoints.first?.x ?? Self.inset.leading, y: Self.inset.top + geometry.plotHeight))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [.teal.opacity(0.22), .teal.opacity(0.02)]),
                startPoint: CGPoint(x: size.width / 2, y: Self.inset.top),
                endPoint: CGPoint(x: size.width / 2, y: Self.inset.top + geometry.plotHeight)
            ))

            // Per-request line (thin, secondary)
            context.stroke(
                smoothedPath(points: perRequestPoints),
                with: .color(.teal.opacity(0.55)),
                lineWidth: 1.4
            )

            // Cumulative line (thick, primary)
            context.stroke(
                smoothedPath(points: cumulativePoints),
                with: .color(.teal),
                lineWidth: 2.4
            )

            // Last point dot
            if let last = cumulativePoints.last {
                context.fill(Path(ellipseIn: CGRect(x: last.x - 3.5, y: last.y - 3.5, width: 7, height: 7)), with: .color(.teal))
                context.stroke(Path(ellipseIn: CGRect(x: last.x - 5.5, y: last.y - 5.5, width: 11, height: 11)), with: .color(.teal.opacity(0.32)), lineWidth: 2)
            }

            // Hover indicator line
            if let hoveredIndex,
               cumulativePoints.indices.contains(hoveredIndex) {
                let point = cumulativePoints[hoveredIndex]
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: point.x, y: Self.inset.top))
                        path.addLine(to: CGPoint(x: point.x, y: Self.inset.top + geometry.plotHeight))
                    },
                    with: .color(.teal.opacity(0.45)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
            }
        }
        .overlay {
            GeometryReader { proxy in
                let geometry = ChartGeometry(size: proxy.size, inset: Self.inset)
                let perRequestPoints = geometry.points(for: samples, value: \.hitRate)
                let cumulativePoints = geometry.points(for: samples, value: \.cumulativeHitRate)

                ZStack {
                    if let hoveredIndex,
                       samples.indices.contains(hoveredIndex) {
                        let sample = samples[hoveredIndex]

                        if perRequestPoints.indices.contains(hoveredIndex) {
                            Circle()
                                .fill(.teal.opacity(0.55))
                                .frame(width: 7, height: 7)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                .position(perRequestPoints[hoveredIndex])
                        }

                        if cumulativePoints.indices.contains(hoveredIndex) {
                            Circle()
                                .fill(.teal)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .position(cumulativePoints[hoveredIndex])
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(Self.tooltipDateFormatter.string(from: sample.date))
                                .font(.system(size: 10, weight: .medium))
                            HStack(spacing: 4) {
                                Text(LumiPluginLocalization.string("This request", bundle: .module))
                                    .foregroundStyle(.secondary)
                                Text(Self.percentText(sample.hitRate))
                                    .monospacedDigit()
                            }
                            .font(.system(size: 10))
                            HStack(spacing: 4) {
                                Text(LumiPluginLocalization.string("Cumulative", bundle: .module))
                                    .foregroundStyle(.secondary)
                                Text(Self.percentText(sample.cumulativeHitRate))
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                            .font(.system(size: 11))
                        }
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(.secondary.opacity(0.25), lineWidth: 0.5)
                        }
                        .shadow(radius: 3, y: 1)
                        .fixedSize()
                        .position(x: min(max(cumulativePoints[hoveredIndex].x, 84), max(proxy.size.width - 84, 84)), y: 42)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case let .active(location):
                        guard !samples.isEmpty else { return }
                        let ratio = (location.x - Self.inset.leading) / geometry.plotWidth
                        let rawIndex = Int((ratio * CGFloat(samples.count - 1)).rounded())
                        hoveredIndex = min(max(rawIndex, 0), samples.count - 1)
                    case .ended:
                        hoveredIndex = nil
                    }
                }
            }
        }
        .background(Color.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.teal.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    /// 百分比展示，命中率过低时保留一位小数避免全部显示为 0%。
    static func percentText(_ rate: Double) -> String {
        let value = rate * 100
        if value > 0 && value < 10 {
            return String(format: "%.1f%%", value)
        }
        return String(format: "%.0f%%", value)
    }

    private static let tooltipDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func smoothedPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        guard points.count > 1 else {
            path.addLine(to: first)
            return path
        }

        for index in 0..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let previous = index > 0 ? points[index - 1] : current
            let afterNext = index + 2 < points.count ? points[index + 2] : next
            let control1 = CGPoint(
                x: current.x + (next.x - previous.x) / 6,
                y: current.y + (next.y - previous.y) / 6
            )
            let control2 = CGPoint(
                x: next.x - (afterNext.x - current.x) / 6,
                y: next.y - (afterNext.y - current.y) / 6
            )
            path.addCurve(to: next, control1: control1, control2: control2)
        }

        return path
    }
}

// MARK: - Chart Geometry

/// 采样点到画布坐标的映射，绘制层与交互层共用，避免两处坐标计算漂移。
private struct ChartGeometry {
    let size: CGSize
    let inset: EdgeInsets

    var plotWidth: CGFloat { max(size.width - inset.leading - inset.trailing, 1) }
    var plotHeight: CGFloat { max(size.height - inset.top - inset.bottom, 1) }

    /// 将采样点映射到画布坐标；纵轴固定 0...1。
    func points(for samples: [CacheHitRateSample], value: KeyPath<CacheHitRateSample, Double>) -> [CGPoint] {
        samples.enumerated().map { offset, sample in
            let xRatio = samples.count == 1 ? 0.5 : Double(offset) / Double(samples.count - 1)
            let yRatio = min(max(sample[keyPath: value], 0), 1)
            return CGPoint(
                x: inset.leading + plotWidth * xRatio,
                y: inset.top + plotHeight * (1 - yRatio)
            )
        }
    }
}

// MARK: - 预览

#if DEBUG
#Preview("Cache Hit Rate Chart") {
    CacheHitRateLineChart(samples: CacheHitRateHistory.preview.samples)
        .frame(width: 340, height: 118)
        .padding()
}
#endif
