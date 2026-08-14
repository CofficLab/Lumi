import SwiftUI

/// 会话流式速度历史折线图（Canvas 绘制，支持 hover 查看采样点）。
struct LineChart: View {
    let samples: [SpeedSample]
    @State private var hoveredIndex: Int?

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty, size.width > 0, size.height > 0 else { return }

            let values = samples.map(\.tokensPerSecond)
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 0
            let range = max(maxValue - minValue, 1)
            let inset = EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
            let plotWidth = max(size.width - inset.leading - inset.trailing, 1)
            let plotHeight = max(size.height - inset.top - inset.bottom, 1)

            let points = samples.enumerated().map { offset, sample in
                let xRatio = samples.count == 1 ? 0.5 : Double(offset) / Double(samples.count - 1)
                let yRatio = (sample.tokensPerSecond - minValue) / range
                return CGPoint(
                    x: inset.leading + plotWidth * xRatio,
                    y: inset.top + plotHeight * (1 - yRatio)
                )
            }

            var grid = Path()
            for step in 0...2 {
                let y = inset.top + plotHeight * Double(step) / 2
                grid.move(to: CGPoint(x: inset.leading, y: y))
                grid.addLine(to: CGPoint(x: inset.leading + plotWidth, y: y))
            }
            context.stroke(grid, with: .color(.secondary.opacity(0.16)), lineWidth: 1)

            var fill = smoothedPath(points: points)
            fill.addLine(to: CGPoint(x: points.last?.x ?? inset.leading, y: inset.top + plotHeight))
            fill.addLine(to: CGPoint(x: points.first?.x ?? inset.leading, y: inset.top + plotHeight))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [.orange.opacity(0.22), .orange.opacity(0.02)]),
                startPoint: CGPoint(x: size.width / 2, y: inset.top),
                endPoint: CGPoint(x: size.width / 2, y: inset.top + plotHeight)
            ))

            context.stroke(smoothedPath(points: points), with: .color(.orange), lineWidth: 2.4)

            if let last = points.last {
                context.fill(Path(ellipseIn: CGRect(x: last.x - 3.5, y: last.y - 3.5, width: 7, height: 7)), with: .color(.orange))
                context.stroke(Path(ellipseIn: CGRect(x: last.x - 5.5, y: last.y - 5.5, width: 11, height: 11)), with: .color(.orange.opacity(0.32)), lineWidth: 2)
            }

            if let hoveredIndex,
               points.indices.contains(hoveredIndex) {
                let point = points[hoveredIndex]
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: point.x, y: inset.top))
                        path.addLine(to: CGPoint(x: point.x, y: inset.top + plotHeight))
                    },
                    with: .color(.orange.opacity(0.45)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
            }
        }
        .overlay {
            GeometryReader { proxy in
                let inset = EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10)
                let plotWidth = max(proxy.size.width - inset.leading - inset.trailing, 1)
                let values = samples.map(\.tokensPerSecond)
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 0
                let range = max(maxValue - minValue, 1)
                let plotHeight = max(proxy.size.height - inset.top - inset.bottom, 1)

                ZStack {
                    if let hoveredIndex,
                       samples.indices.contains(hoveredIndex) {
                        let sample = samples[hoveredIndex]
                        let xRatio = samples.count == 1 ? 0.5 : Double(hoveredIndex) / Double(samples.count - 1)
                        let x = inset.leading + plotWidth * xRatio
                        let yRatio = (sample.tokensPerSecond - minValue) / range
                        let y = inset.top + plotHeight * (1 - yRatio)

                        Circle()
                            .fill(.orange)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .position(x: x, y: y)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(Self.tooltipDateFormatter.string(from: sample.createdAt))
                                .font(.system(size: 10, weight: .medium))
                            Text("X: \(Self.tooltipDateFormatter.string(from: sample.createdAt))")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(String(format: "Y: %.1f tokens/s", sample.tokensPerSecond))
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                        }
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(.secondary.opacity(0.25), lineWidth: 0.5)
                        }
                        .shadow(radius: 3, y: 1)
                        .fixedSize()
                        .position(x: min(max(x, 82), max(proxy.size.width - 82, 82)), y: 34)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case let .active(location):
                        guard !samples.isEmpty else { return }
                        let ratio = (location.x - inset.leading) / plotWidth
                        let rawIndex = Int((ratio * CGFloat(samples.count - 1)).rounded())
                        hoveredIndex = min(max(rawIndex, 0), samples.count - 1)
                    case .ended:
                        hoveredIndex = nil
                    }
                }
            }
        }
        .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
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
