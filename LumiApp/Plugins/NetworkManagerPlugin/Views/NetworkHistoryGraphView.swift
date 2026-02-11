import MagicKit
import SwiftUI

struct NetworkHistoryGraphView: View {
    let dataPoints: [NetworkDataPoint]
    let timeRange: TimeRange

    @State private var hoverLocation: CGPoint?
    @State private var hoverDataPoint: NetworkDataPoint?

    private let yAxisWidth: CGFloat = 50
    private let xAxisHeight: CGFloat = 30

    var body: some View {
        VStack(spacing: 0) {
            // 图表区域（包含 y 轴）
            HStack(spacing: 0) {
                // Y 轴
                yAxisView
                    .frame(width: yAxisWidth)

                // 主图表
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        // 背景网格
                        gridLines(for: geometry.size)

                        if !dataPoints.isEmpty {
                            // Download Graph (Green)
                            GraphArea(data: dataPoints.map { $0.downloadSpeed }, maxValue: maxValue)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [DesignTokens.Color.semantic.success.opacity(0.5), DesignTokens.Color.semantic.success.opacity(0.1)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            GraphLine(data: dataPoints.map { $0.downloadSpeed }, maxValue: maxValue)
                                .stroke(DesignTokens.Color.semantic.success, lineWidth: 1.5)

                            // Upload Graph (Red)
                            GraphArea(data: dataPoints.map { $0.uploadSpeed }, maxValue: maxValue)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [DesignTokens.Color.semantic.error.opacity(0.5), DesignTokens.Color.semantic.error.opacity(0.1)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            GraphLine(data: dataPoints.map { $0.uploadSpeed }, maxValue: maxValue)
                                .stroke(DesignTokens.Color.semantic.error, lineWidth: 1.5)
                        } else {
                            Text("收集数据中...")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        // Hover Overlay
                        if let hoverLocation = hoverLocation, let point = hoverDataPoint {
                            // Vertical Line
                            Path { path in
                                path.move(to: CGPoint(x: hoverLocation.x, y: 0))
                                path.addLine(to: CGPoint(x: hoverLocation.x, y: geometry.size.height))
                            }
                            .stroke(DesignTokens.Color.semantic.textPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            // Info Tooltip
                            TooltipView(point: point, timeRange: timeRange)
                                .position(x: clampedX(hoverLocation.x, width: geometry.size.width), y: 40)
                        }
                    }
                    .background(DesignTokens.Material.glass.opacity(0.01))
                    .onContinuousHover { phase in
                        switch phase {
                        case let .active(location):
                            hoverLocation = location
                            updateHoverDataPoint(at: location.x, width: geometry.size.width)
                        case .ended:
                            hoverLocation = nil
                            hoverDataPoint = nil
                        }
                    }
                }
            }

            // X 轴
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

                // Y 轴标签（从上到下，5 个刻度）
                ForEach(0..<5, id: \.self) { index in
                    if index > 0 {
                        Text(formatYValue(for: index))
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .frame(height: geometry.size.height / 5, alignment: .trailing)
                    }
                }

                // 底部 0 标签
                Text("0")
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .padding(.trailing, 4)
        }
    }

    // MARK: - X Axis View

    private var xAxisView: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: yAxisWidth)

            GeometryReader { geometry in
                HStack {
                    // 左边界时间
                    if let firstPoint = dataPoints.first {
                        Text(formatXAxisDate(firstPoint.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }

                    Spacer()

                    // 右边界时间
                    if let lastPoint = dataPoints.last {
                        Text(formatXAxisDate(lastPoint.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Grid Lines

    private func gridLines(for size: CGSize) -> some View {
        ZStack {
            // 水平网格线（与 y 轴刻度对应）
            ForEach(1..<5, id: \.self) { index in
                Path { path in
                    let y = size.height - (CGFloat(index) / 5) * size.height
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.2), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Formatting Helpers

    private func formatYValue(for index: Int) -> String {
        let value = maxValue * (1.0 - Double(index) / 5.0)
        if value >= 1024 * 1024 * 1024 {
            return String(format: "%.1fG", value / (1024 * 1024 * 1024))
        } else if value >= 1024 * 1024 {
            return String(format: "%.0fM", value / (1024 * 1024))
        } else if value >= 1024 {
            return String(format: "%.0fK", value / 1024)
        } else {
            return String(format: "%.0f", value)
        }
    }

    private func formatXAxisDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        if timeRange == .hour1 {
            formatter.dateFormat = "HH:mm"
        } else if timeRange == .hour4 {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM-dd"
        }
        return formatter.string(from: date)
    }

    private var maxValue: Double {
        let maxDown = dataPoints.map { $0.downloadSpeed }.max() ?? 0
        let maxUp = dataPoints.map { $0.uploadSpeed }.max() ?? 0
        return max(max(maxDown, maxUp) * 1.1, 1024 * 10) // Min 10KB/s scale
    }

    private func updateHoverDataPoint(at x: CGFloat, width: CGFloat) {
        guard !dataPoints.isEmpty else { return }
        // Map x to index
        // x=0 -> index 0, x=width -> index count-1
        let ratio = x / width
        let index = Int(ratio * CGFloat(dataPoints.count - 1))
        let clampedIndex = min(max(index, 0), dataPoints.count - 1)
        hoverDataPoint = dataPoints[clampedIndex]
    }

    private func clampedX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        // Tooltip width is approx 140?
        // Let's keep it inside bounds
        return min(max(x, 70), width - 70)
    }
}

struct TooltipView: View {
    let point: NetworkDataPoint
    let timeRange: TimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDate(point.timestamp))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle().fill(DesignTokens.Color.semantic.success).frame(width: 6, height: 6)
                    Text(point.downloadSpeed.formattedNetworkSpeed())
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }

                HStack(spacing: 4) {
                    Circle().fill(DesignTokens.Color.semantic.error).frame(width: 6, height: 6)
                    Text(point.uploadSpeed.formattedNetworkSpeed())
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }
            }
        }
        .padding(8)
        .background(DesignTokens.Material.glass)
        .cornerRadius(6)
        .shadow(radius: 2)
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        if timeRange == .hour1 || timeRange == .hour4 {
            formatter.dateFormat = "HH:mm:ss"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
        }
        return formatter.string(from: date)
    }
}

// Custom Shape for Filled Area
struct GraphArea: Shape {
    let data: [Double]
    let maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty, maxValue > 0 else { return path }

        let stepX = rect.width / CGFloat(data.count - 1)
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height))

        for (i, value) in data.enumerated() {
            let x = CGFloat(i) * stepX
            let y = height - CGFloat(value / maxValue) * height
            if i == 0 {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * stepX, y: height))
        path.closeSubpath()

        return path
    }
}

// Custom Shape for Line Stroke
struct GraphLine: Shape {
    let data: [Double]
    let maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty, maxValue > 0 else { return path }

        let stepX = rect.width / CGFloat(data.count - 1)
        let height = rect.height

        for (i, value) in data.enumerated() {
            let x = CGFloat(i) * stepX
            let y = height - CGFloat(value / maxValue) * height
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

// Helper for VisualEffectView
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = state
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = state
    }
}

// MARK: - Preview

#Preview("Network Status Bar Popup") {
    NetworkStatusBarPopupView()
        .frame(width: 300)
        .frame(height: 400)
}
