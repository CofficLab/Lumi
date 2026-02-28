import SwiftUI
import Combine
import AppKit

struct CPUHistoryGraphView: View {
    let dataPoints: [CPUDataPoint]
    let timeRange: CPUTimeRange

    @State private var hoverLocation: CGPoint?
    @State private var hoverDataPoint: CPUDataPoint?

    private let yAxisWidth: CGFloat = 40
    private let xAxisHeight: CGFloat = 30

    // Y-axis max value logic
    private var maxValue: Double {
        // CPU usage is 0-100%
        return 100.0
    }

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
                            // Usage Area
                            CPUGraphArea(data: dataPoints.map { $0.usage }, maxValue: maxValue)
                                .fill(LinearGradient(gradient: Gradient(colors: [DesignTokens.Color.semantic.info.opacity(0.5), DesignTokens.Color.semantic.info.opacity(0.1)]), startPoint: .top, endPoint: .bottom))

                            // Usage Line
                            CPUGraphLine(data: dataPoints.map { $0.usage }, maxValue: maxValue)
                                .stroke(DesignTokens.Color.semantic.info, lineWidth: 1.5)
                        } else {
                            Text("收集数据中...")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        // Hover Interaction
                        if let hoverLocation = hoverLocation, let point = hoverDataPoint {
                            // Vertical Line
                            Path { path in
                                path.move(to: CGPoint(x: hoverLocation.x, y: 0))
                                path.addLine(to: CGPoint(x: hoverLocation.x, y: geometry.size.height))
                            }
                            .stroke(DesignTokens.Color.semantic.textPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            // Tooltip
                            CPUTooltipView(point: point, timeRange: timeRange)
                                .position(x: clampedX(hoverLocation.x, width: geometry.size.width), y: 40)
                        }
                    }
                    .contentShape(Rectangle()) // Ensure entire area is hittable
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
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                            .frame(height: geometry.size.height / 5, alignment: .trailing)
                    }
                }

                // 底部 0 标签
                Text("0")
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
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
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }

                    Spacer()

                    // 右边界时间
                    if let lastPoint = dataPoints.last {
                        Text(formatXAxisDate(lastPoint.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
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
                .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.15), lineWidth: 0.5)
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
        // Keep tooltip within bounds
        let tooltipWidth: CGFloat = 140
        return max(tooltipWidth/2, min(width - tooltipWidth/2, x))
    }
}

// MARK: - Shapes

struct CPUGraphLine: Shape {
    var data: [Double]
    var maxValue: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }
        
        let stepX = rect.width / CGFloat(data.count - 1)
        let scaleY = rect.height / CGFloat(maxValue)
        
        path.move(to: CGPoint(x: 0, y: rect.height - CGFloat(data[0]) * scaleY))
        
        for index in 1..<data.count {
            let x = CGFloat(index) * stepX
            let y = rect.height - CGFloat(data[index]) * scaleY
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

struct CPUGraphArea: Shape {
    var data: [Double]
    var maxValue: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }
        
        let stepX = rect.width / CGFloat(data.count - 1)
        let scaleY = rect.height / CGFloat(maxValue)
        
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height - CGFloat(data[0]) * scaleY))
        
        for index in 1..<data.count {
            let x = CGFloat(index) * stepX
            let y = rect.height - CGFloat(data[index]) * scaleY
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Tooltip

struct CPUTooltipView: View {
    let point: CPUDataPoint
    let timeRange: CPUTimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDate(point.timestamp))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(DesignTokens.Color.semantic.info)
                    .frame(width: 6, height: 6)
                Text("\(Int(point.usage))%")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        }
        .padding(6)
        .background(DesignTokens.Material.glass)
        .cornerRadius(6)
        .shadow(radius: 2)
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
    CPUStatusBarPopupView()
        .inRootView()
        .frame(width: 300)
        .frame(height: 300)
}
