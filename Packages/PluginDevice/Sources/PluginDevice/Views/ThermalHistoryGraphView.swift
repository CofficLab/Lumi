import SwiftUI
import LumiUI

/// CPU / die 温度历史曲线。
///
/// 与 ``CPUHistoryGraphView`` 结构一致(坐标轴 / 网格 / 悬停提示),
/// 区别在于 Y 轴为摄氏度,且量程随数据自适应,避免固定 0–100 把曲线压成一条平线。
struct ThermalHistoryGraphView: View {
    let dataPoints: [ThermalDataPoint]
    let timeRange: CPUTimeRange

    @State private var hoverLocation: CGPoint?
    @State private var hoverDataPoint: ThermalDataPoint?

    private let yAxisWidth: CGFloat = 40
    private let xAxisHeight: CGFloat = 30

    /// Y 轴上界(℃)。以 50℃ 为下限,向上按 10℃ 步进取整,保证曲线有可读起伏。
    private var maxValue: Double {
        guard let peak = dataPoints.map(\.celsius).max() else { return 100 }
        return max(50, (peak / 10).rounded(.up) * 10 + 10)
    }

    /// Y 轴下界(℃)。低于 20℃ 的读数没有实际意义,固定从 0 起画即可。
    private var minValue: Double { 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                yAxisView
                    .frame(width: yAxisWidth)

                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        gridLines(for: geometry.size)

                        if !dataPoints.isEmpty {
                            ThermalGraphArea(
                                data: dataPoints.map(\.celsius),
                                minValue: minValue,
                                maxValue: maxValue
                            )
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.orange.opacity(0.45),
                                        Color.orange.opacity(0.08),
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            ThermalGraphLine(
                                data: dataPoints.map(\.celsius),
                                minValue: minValue,
                                maxValue: maxValue
                            )
                            .stroke(.orange, lineWidth: 1.5)
                        } else {
                            Text(pluginLocalization.string("Collecting..."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        if let hoverLocation, let point = hoverDataPoint {
                            Path { path in
                                path.move(to: CGPoint(x: hoverLocation.x, y: 0))
                                path.addLine(to: CGPoint(x: hoverLocation.x, y: geometry.size.height))
                            }
                            .stroke(Color.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            ThermalTooltipView(point: point, timeRange: timeRange)
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

                ForEach(0..<5, id: \.self) { index in
                    if index > 0 {
                        Text(formatYValue(for: index))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(height: geometry.size.height / 5, alignment: .trailing)
                    }
                }

                Text(verbatim: "\(Int(minValue))°")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let lastPoint = dataPoints.last {
                        Text(formatXAxisDate(lastPoint.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Grid Lines

    private func gridLines(for size: CGSize) -> some View {
        ZStack {
            ForEach(1..<5, id: \.self) { index in
                Path { path in
                    let y = size.height - (CGFloat(index) / 5) * size.height
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Formatting Helpers

    private func formatYValue(for index: Int) -> String {
        let value = maxValue - (maxValue - minValue) * Double(index) / 5.0
        return "\(Int(value))°"
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

// MARK: - Shapes

struct ThermalGraphLine: Shape {
    var data: [Double]
    var minValue: Double
    var maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let span = maxValue - minValue
        guard data.count > 1, span.isFinite, span > 0 else { return path }

        let stepX = rect.width / CGFloat(data.count - 1)
        let scaleY = rect.height / CGFloat(span)

        path.move(to: CGPoint(x: 0, y: rect.height - CGFloat(data[0] - minValue) * scaleY))

        for index in 1..<data.count {
            let x = CGFloat(index) * stepX
            let y = rect.height - CGFloat(data[index] - minValue) * scaleY
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

struct ThermalGraphArea: Shape {
    var data: [Double]
    var minValue: Double
    var maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let span = maxValue - minValue
        guard data.count > 1, span.isFinite, span > 0 else { return path }

        let stepX = rect.width / CGFloat(data.count - 1)
        let scaleY = rect.height / CGFloat(span)

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height - CGFloat(data[0] - minValue) * scaleY))

        for index in 1..<data.count {
            let x = CGFloat(index) * stepX
            let y = rect.height - CGFloat(data[index] - minValue) * scaleY
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Tooltip

struct ThermalTooltipView: View {
    let point: ThermalDataPoint
    let timeRange: CPUTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDate(point.timestamp))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.primary)

            HStack(spacing: 4) {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                Text(String(format: "%.1f°C", point.celsius))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(6)
        .background(Material.regularMaterial)
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
