import AppKit
import Combine
import SwiftUI

struct MemoryHistoryGraphView: View {
    let dataPoints: [MemoryDataPoint]
    let timeRange: MemoryTimeRange

    @State private var hoverLocation: CGPoint?
    @State private var hoverDataPoint: MemoryDataPoint?

    private let yAxisWidth: CGFloat = 40
    private let xAxisHeight: CGFloat = 30
    private let maxValue: Double = 100.0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                yAxisView
                    .frame(width: yAxisWidth)

                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        gridLines(for: geometry.size)

                        if !dataPoints.isEmpty {
                            MemoryGraphArea(data: dataPoints.map { $0.usagePercentage }, maxValue: maxValue)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            AppUI.Color.semantic.primary.opacity(0.5),
                                            AppUI.Color.semantic.primary.opacity(0.1),
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            MemoryGraphLine(data: dataPoints.map { $0.usagePercentage }, maxValue: maxValue)
                                .stroke(AppUI.Color.semantic.primary, lineWidth: 1.5)
                        } else {
                            Text("Collecting data...")
                                .font(.caption)
                                .foregroundColor(AppUI.Color.semantic.textSecondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        if let hoverLocation, let point = hoverDataPoint {
                            Path { path in
                                path.move(to: CGPoint(x: hoverLocation.x, y: 0))
                                path.addLine(to: CGPoint(x: hoverLocation.x, y: geometry.size.height))
                            }
                            .stroke(AppUI.Color.semantic.textPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            MemoryTooltipView(point: point, timeRange: timeRange)
                                .position(x: clampedX(hoverLocation.x, width: geometry.size.width), y: 40)
                        }
                    }
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoverLocation = location
                            updateHoverDataPoint(at: location.x, width: geometry.size.width)
                        case .ended:
                            hoverLocation = nil
                            hoverDataPoint = nil
                        }
                    }
                }
            }

            xAxisView
                .frame(height: xAxisHeight)
        }
        .padding()
    }

    // MARK: - Y Axis View

    private var yAxisView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()

                ForEach(0 ..< 5, id: \.self) { index in
                    if index > 0 {
                        Text(formatYValue(for: index))
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                            .frame(height: geometry.size.height / 5, alignment: .trailing)
                    }
                }

                Text("0")
                    .font(.system(size: 9))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
            .padding(.trailing, 4)
        }
    }

    // MARK: - X Axis View

    private var xAxisView: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: yAxisWidth)

            GeometryReader { _ in
                HStack {
                    if let firstPoint = dataPoints.first {
                        Text(formatXAxisDate(firstPoint.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                    }

                    Spacer()

                    if let lastPoint = dataPoints.last {
                        Text(formatXAxisDate(lastPoint.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Grid Lines

    private func gridLines(for size: CGSize) -> some View {
        ZStack {
            ForEach(1 ..< 5, id: \.self) { index in
                Path { path in
                    let y = size.height - (CGFloat(index) / 5) * size.height
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(AppUI.Color.semantic.textTertiary.opacity(0.15), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Formatting Helpers

    private func formatYValue(for index: Int) -> String {
        let value = maxValue * (1.0 - Double(index) / 5.0)
        return "\(Int(value))%"
    }

    private func formatXAxisDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        switch timeRange {
        case .hour1, .hour4:
            formatter.dateFormat = "HH:mm"
        default:
            formatter.dateFormat = "MM-dd"
        }
        return formatter.string(from: date)
    }

    private func updateHoverDataPoint(at x: CGFloat, width: CGFloat) {
        guard !dataPoints.isEmpty else { return }
        let index = Int(x / width * CGFloat(dataPoints.count - 1))
        let safeIndex = max(0, min(dataPoints.count - 1, index))
        hoverDataPoint = dataPoints[safeIndex]
    }

    private func clampedX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        let tooltipWidth: CGFloat = 140
        return max(tooltipWidth / 2, min(width - tooltipWidth / 2, x))
    }
}

struct MemoryGraphLine: Shape {
    var data: [Double]
    var maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }
        let stepX = rect.width / CGFloat(data.count - 1)
        let scaleY = rect.height / CGFloat(maxValue)
        path.move(to: CGPoint(x: 0, y: rect.height - CGFloat(data[0]) * scaleY))
        for index in 1 ..< data.count {
            path.addLine(to: CGPoint(x: CGFloat(index) * stepX, y: rect.height - CGFloat(data[index]) * scaleY))
        }
        return path
    }
}

struct MemoryGraphArea: Shape {
    var data: [Double]
    var maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }
        let stepX = rect.width / CGFloat(data.count - 1)
        let scaleY = rect.height / CGFloat(maxValue)
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height - CGFloat(data[0]) * scaleY))
        for index in 1 ..< data.count {
            path.addLine(to: CGPoint(x: CGFloat(index) * stepX, y: rect.height - CGFloat(data[index]) * scaleY))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct MemoryTooltipView: View {
    let point: MemoryDataPoint
    let timeRange: MemoryTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDate(point.timestamp))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            HStack(spacing: 4) {
                Circle()
                    .fill(AppUI.Color.semantic.primary)
                    .frame(width: 6, height: 6)
                Text("\(ByteCountFormatter.string(fromByteCount: Int64(point.usedBytes), countStyle: .memory)) (\(Int(point.usagePercentage))%)")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
        }
        .padding(6)
        .background(AppUI.Material.glass)
        .cornerRadius(6)
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        switch timeRange {
        case .hour1, .hour4:
            formatter.dateFormat = "HH:mm:ss"
        default:
            formatter.dateFormat = "MM-dd HH:mm"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("App") {
    MemoryStatusBarPopupView()
        .inRootView()
        .frame(width: 400)
        .frame(height: 400)
}
