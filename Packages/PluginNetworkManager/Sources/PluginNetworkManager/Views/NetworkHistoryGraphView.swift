import LumiUI
import SwiftUI
import KernelCore

/// 图表的几何量。
///
/// 一次 body 求值只算一次，供所有 Shape 共用：
/// 原先每个 Shape 各自拿一份 `dataPoints.map { ... }`，
/// `maxValue` 与 `timeFractions` 也是计算属性 —— 一次求值要跑
/// 4 次全量 map 加 2 次全量扫描，鼠标每移动一次就重跑一遍
/// （见 issue #1211）。
struct ChartGeometry {
    /// 下载速率序列。
    let downloadValues: [Double]
    /// 上传速率序列。
    let uploadValues: [Double]
    /// 纵轴最大值。
    let maxValue: Double
    /// 每个点在图表中的水平位置（0...1）。
    let timeFractions: [Double]?

    init(points: [NetworkDataPoint]) {
        var download: [Double] = []
        var upload: [Double] = []
        download.reserveCapacity(points.count)
        upload.reserveCapacity(points.count)
        var maxDown: Double = 0
        var maxUp: Double = 0

        for point in points {
            download.append(point.downloadSpeed)
            upload.append(point.uploadSpeed)
            if point.downloadSpeed > maxDown { maxDown = point.downloadSpeed }
            if point.uploadSpeed > maxUp { maxUp = point.uploadSpeed }
        }

        self.downloadValues = download
        self.uploadValues = upload
        self.maxValue = max(max(maxDown, maxUp) * 1.1, 1024 * 10) // Min 10KB/s scale
        self.timeFractions = NetworkHistoryGraphView.timeFractions(for: points)
    }
}

public struct NetworkHistoryGraphView: View {
    public let dataPoints: [NetworkDataPoint]
    public let timeRange: TimeRange

    @State private var hoverLocation: CGPoint?
    @State private var hoverDataPoint: NetworkDataPoint?

    private let yAxisWidth: CGFloat = 50
    private let xAxisHeight: CGFloat = 30

    public var body: some View {
        // 几何量在这里一次性算好，body 内部不再重复计算。
        //
        // - Important: 原先每个图表 Shape 都各自拿一份 `dataPoints.map { ... }`，
        //   `maxValue` 与 `timeFractions` 也是计算属性 —— 一次 body 求值要跑
        //   4 次全量 map 加 2 次全量扫描。鼠标在图上移动时每次 hover 更新
        //   都会重跑一遍，30 天范围下是数万次元素操作（见 issue #1211）。
        let geometry = ChartGeometry(points: dataPoints)

        VStack(spacing: 0) {
            // 图表区域（包含 y 轴）
            HStack(spacing: 0) {
                // Y 轴
                yAxisView(maxValue: geometry.maxValue)
                    .frame(width: yAxisWidth)

                // 主图表
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        // 背景网格
                        gridLines(for: proxy.size)

                        if !dataPoints.isEmpty {
                            // Download Graph (Green)
                            MiniGraphArea(
                                data: geometry.downloadValues,
                                maxValue: geometry.maxValue,
                                xFractions: geometry.timeFractions
                            )
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.green.opacity(0.5), Color.green.opacity(0.1)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            MiniGraphLine(
                                data: geometry.downloadValues,
                                maxValue: geometry.maxValue,
                                xFractions: geometry.timeFractions
                            )
                                .stroke(.green, lineWidth: 1.5)

                            // Upload Graph (Red)
                            MiniGraphArea(
                                data: geometry.uploadValues,
                                maxValue: geometry.maxValue,
                                xFractions: geometry.timeFractions
                            )
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.red.opacity(0.5), Color.red.opacity(0.1)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            MiniGraphLine(
                                data: geometry.uploadValues,
                                maxValue: geometry.maxValue,
                                xFractions: geometry.timeFractions
                            )
                                .stroke(.red, lineWidth: 1.5)
                        } else {
                            Text(pluginLocalization.string("Collecting data..."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        // Hover Overlay
                        if let hoverLocation = hoverLocation, let point = hoverDataPoint {
                            // Vertical Line
                            Path { path in
                                path.move(to: CGPoint(x: hoverLocation.x, y: 0))
                                path.addLine(to: CGPoint(x: hoverLocation.x, y: proxy.size.height))
                            }
                            .stroke(Color.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            // Info Tooltip
                            TooltipView(point: point, timeRange: timeRange)
                                .position(x: clampedX(hoverLocation.x, width: proxy.size.width), y: 40)
                        }
                    }
                    .background(Color.white.opacity(0.01))
                    .onContinuousHover { phase in
                        switch phase {
                        case let .active(location):
                            hoverLocation = location
                            updateHoverDataPoint(at: location.x, width: proxy.size.width)
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

    private func yAxisView(maxValue: Double) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()

                // Y 轴标签（从上到下，5 个刻度）
                ForEach(0..<5, id: \.self) { index in
                    if index > 0 {
                        Text(formatYValue(for: index, maxValue: maxValue))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(height: geometry.size.height / 5, alignment: .trailing)
                    }
                }

                // 底部 0 标签
                Text(verbatim: pluginLocalization.string("0"))
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

            GeometryReader { geometry in
                HStack {
                    // 左边界时间
                    if let firstPoint = dataPoints.first {
                        Text(formatXAxisDate(firstPoint.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 右边界时间
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
            // 水平网格线（与 y 轴刻度对应）
            ForEach(1..<5, id: \.self) { index in
                Path { path in
                    let y = size.height - (CGFloat(index) / 5) * size.height
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Formatting Helpers

    private func formatYValue(for index: Int, maxValue: Double) -> String {
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

    private func updateHoverDataPoint(at x: CGFloat, width: CGFloat) {
        guard !dataPoints.isEmpty, width > 0 else { return }
        let fraction = Double(min(max(x / width, 0), 1))
        if let index = Self.nearestIndex(forXFraction: fraction, in: dataPoints) {
            hoverDataPoint = dataPoints[index]
        }
    }

    /// 每个点在图表中的水平位置（0...1），按真实时间戳线性映射。
    /// 点数不足或时间跨度为 0 时返回 nil，交由图表退回等距布局。
    static func timeFractions(for points: [NetworkDataPoint]) -> [Double]? {
        guard points.count > 1,
              let first = points.first?.timestamp,
              let last = points.last?.timestamp,
              last > first
        else { return nil }
        let span = last - first
        return points.map { min(max(($0.timestamp - first) / span, 0), 1) }
    }

    /// 按同一时间映射把水平位置换算为目标时间，取最接近的数据点下标。
    static func nearestIndex(forXFraction fraction: Double, in points: [NetworkDataPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        guard timeFractions(for: points) != nil,
              let first = points.first?.timestamp,
              let last = points.last?.timestamp
        else {
            // 单点或同一时刻：没有可用的时间轴，退回数组下标。
            let clamped = min(max(fraction, 0), 1)
            let index = Int((clamped * Double(points.count - 1)).rounded())
            return min(max(index, 0), points.count - 1)
        }
        let target = first + min(max(fraction, 0), 1) * (last - first)
        var bestIndex = 0
        var bestDelta = Double.infinity
        for (index, point) in points.enumerated() {
            let delta = abs(point.timestamp - target)
            if delta < bestDelta {
                bestDelta = delta
                bestIndex = index
            }
        }
        return bestIndex
    }

    private func clampedX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        // Tooltip width is approx 140?
        // Let's keep it inside bounds
        return min(max(x, 70), width - 70)
    }
}

public struct TooltipView: View {
    public let point: NetworkDataPoint
    public let timeRange: TimeRange

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDate(point.timestamp))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text(point.downloadSpeed.formattedNetworkSpeed())
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }

                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text(point.uploadSpeed.formattedNetworkSpeed())
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }
            }
        }
        .padding(8)
        .background(Material.regularMaterial)
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

// MARK: - Preview

#Preview("Network Status Bar Popup") {
    NetworkMenuBarPopupView()
        .frame(width: 300)
        .frame(height: 400)
}
