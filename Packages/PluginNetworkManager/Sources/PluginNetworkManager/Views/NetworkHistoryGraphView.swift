import LumiUI
import SwiftUI
import KernelCore

/// 图表的几何量。
///
/// 由只依赖 `dataPoints` 的静态子视图构建（见 ``NetworkHistoryPlot``）：
/// hover 状态变化时 SwiftUI 跳过子视图更新，几何量不再重建。
/// 原先几何量在每次 body 求值时重算，每个 Shape 还各自拿一份
/// `dataPoints.map { ... }`，鼠标每移动一次就重跑一遍（见 issue #1211）。
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

        for point in points {
            download.append(point.downloadSpeed)
            upload.append(point.uploadSpeed)
        }

        self.downloadValues = download
        self.uploadValues = upload
        self.maxValue = Self.maxValue(of: points)
        self.timeFractions = NetworkHistoryGraphView.timeFractions(for: points)
    }

    /// 纵轴最大值：上下行峰值取较大者，留 10% 余量，并有 10KB/s 下限。
    static func maxValue(of points: [NetworkDataPoint]) -> Double {
        var maxDown: Double = 0
        var maxUp: Double = 0
        for point in points {
            if point.downloadSpeed > maxDown { maxDown = point.downloadSpeed }
            if point.uploadSpeed > maxUp { maxUp = point.uploadSpeed }
        }
        return max(max(maxDown, maxUp) * 1.1, 1024 * 10) // Min 10KB/s scale
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
        VStack(spacing: 0) {
            // 图表区域（包含 y 轴）
            HStack(spacing: 0) {
                // Y 轴
                NetworkHistoryYAxis(dataPoints: dataPoints)
                    .frame(width: yAxisWidth)

                // 主图表
                GeometryReader { proxy in
                    NetworkHistoryPlot(dataPoints: dataPoints)
                        .overlay {
                            hoverOverlay(in: proxy.size)
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
            NetworkHistoryXAxis(dataPoints: dataPoints, timeRange: timeRange, yAxisWidth: yAxisWidth)
                .frame(height: xAxisHeight)
        }
        .padding()
    }

    // MARK: - Hover Overlay

    @ViewBuilder
    private func hoverOverlay(in size: CGSize) -> some View {
        if let hoverLocation, let point = hoverDataPoint {
            // Vertical Line
            Path { path in
                path.move(to: CGPoint(x: hoverLocation.x, y: 0))
                path.addLine(to: CGPoint(x: hoverLocation.x, y: size.height))
            }
            .stroke(Color.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            // Info Tooltip
            TooltipView(point: point, timeRange: timeRange)
                .position(x: clampedX(hoverLocation.x, width: size.width), y: 40)
        }
    }

    // MARK: - Formatting Helpers

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
    ///
    /// 时间戳按顺序排列，直接二分查找；原先这里先全量分配 `timeFractions`
    /// 仅为了判空，再线性扫全部点，30 天范围下每次 hover 都是数万次比较
    /// （见 issue #1211）。
    static func nearestIndex(forXFraction fraction: Double, in points: [NetworkDataPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        let clamped = min(max(fraction, 0), 1)
        guard points.count > 1,
              let first = points.first?.timestamp,
              let last = points.last?.timestamp,
              last > first
        else {
            // 单点或同一时刻：没有可用的时间轴，退回数组下标。
            let index = Int((clamped * Double(points.count - 1)).rounded())
            return min(max(index, 0), points.count - 1)
        }
        let target = first + clamped * (last - first)
        var low = 0
        var high = points.count - 1
        while low < high {
            let mid = (low + high) / 2
            if points[mid].timestamp < target {
                low = mid + 1
            } else {
                high = mid
            }
        }
        // low 是第一个 >= target 的下标；与前一个点比较取更近者（并列取较早者）。
        if low > 0,
           abs(points[low - 1].timestamp - target) <= abs(points[low].timestamp - target) {
            return low - 1
        }
        return low
    }

    private func clampedX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        // Tooltip width is approx 140?
        // Let's keep it inside bounds
        return min(max(x, 70), width - 70)
    }
}

/// 只依赖 `dataPoints` 的 Y 轴刻度。
///
/// hover 状态变化时 SwiftUI 跳过其更新，纵轴最大值的全量扫描不再重跑（#1211）。
private struct NetworkHistoryYAxis: View {
    let dataPoints: [NetworkDataPoint]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()

                // Y 轴标签（从上到下，5 个刻度）
                ForEach(0..<5, id: \.self) { index in
                    if index > 0 {
                        Text(formatYValue(for: index))
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

    private func formatYValue(for index: Int) -> String {
        let value = ChartGeometry.maxValue(of: dataPoints) * (1.0 - Double(index) / 5.0)
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
}

/// 只依赖 `dataPoints` 的主绘图区：网格 + 四个图形。
///
/// hover 状态变化时 SwiftUI 跳过其更新，几何量与路径不再重建（#1211）。
private struct NetworkHistoryPlot: View {
    let dataPoints: [NetworkDataPoint]

    var body: some View {
        GeometryReader { proxy in
            let geometry = ChartGeometry(points: dataPoints)

            ZStack(alignment: .topLeading) {
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
            }
        }
    }

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
}

/// 只依赖 `dataPoints` 与 `timeRange` 的 X 轴。
///
/// hover 状态变化时 SwiftUI 跳过其更新，日期格式化不再重跑（#1211）。
private struct NetworkHistoryXAxis: View {
    let dataPoints: [NetworkDataPoint]
    let timeRange: TimeRange
    let yAxisWidth: CGFloat

    var body: some View {
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
