import SwiftUI

struct GPUHistoryGraphView: View {
    let dataPoints: [GPUDataPoint]
    let timeRange: GPUTimeRange

    @State private var hoverLocation: CGPoint?
    @State private var hoverDataPoint: GPUDataPoint?

    private let yAxisWidth: CGFloat = 40
    private let xAxisHeight: CGFloat = 30

    // GPU usage is 0-100%
    private var maxValue: Double { 100.0 }

    var body: some View {
        VStack(spacing: 0) {
            // Chart area (includes y-axis)
            HStack(spacing: 0) {
                yAxisView
                    .frame(width: yAxisWidth)

                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        // Background grid
                        gridLines(for: geometry.size)

                        if !dataPoints.isEmpty {
                            // Usage Area
                            GPUGraphArea(data: dataPoints.map { $0.usage }, maxValue: maxValue)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "BF5AF2").opacity(0.5),
                                        Color(hex: "BF5AF2").opacity(0.1),
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))

                            // Usage Line
                            GPUGraphLine(data: dataPoints.map { $0.usage }, maxValue: maxValue)
                                .stroke(Color(hex: "BF5AF2"), lineWidth: 1.5)
                        } else {
                            Text(LumiPluginLocalization.string("Collecting...", bundle: .module))
                                .font(.caption)
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        // Hover interaction
                        if let hoverLocation, let point = hoverDataPoint {
                            Path { path in
                                path.move(to: CGPoint(x: hoverLocation.x, y: 0))
                                path.addLine(to: CGPoint(x: hoverLocation.x, y: geometry.size.height))
                            }
                            .stroke(
                                Color.adaptive(light: "1C1C1E", dark: "FFFFFF").opacity(0.3),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )

                            GPUTooltipView(point: point, timeRange: timeRange)
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

            // X-axis
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
                            .foregroundColor(Color(hex: "98989E"))
                            .frame(height: geometry.size.height / 5, alignment: .trailing)
                    }
                }

                Text(verbatim: LumiPluginLocalization.string("0", bundle: .module))
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "98989E"))
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
                    if let firstPoint = dataPoints.first {
                        Text(formatXAxisDate(firstPoint.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "98989E"))
                    }

                    Spacer()

                    if let lastPoint = dataPoints.last {
                        Text(formatXAxisDate(lastPoint.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "98989E"))
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
                .stroke(Color(hex: "98989E").opacity(0.15), lineWidth: 0.5)
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

// MARK: - Shapes

struct GPUGraphLine: Shape {
    var data: [Double]
    var maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1, maxValue.isFinite, maxValue > 0 else { return path }

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

struct GPUGraphArea: Shape {
    var data: [Double]
    var maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1, maxValue.isFinite, maxValue > 0 else { return path }

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

struct GPUTooltipView: View {
    let point: GPUDataPoint
    let timeRange: GPUTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDate(point.timestamp))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: "BF5AF2"))
                    .frame(width: 6, height: 6)
                Text("\(Int(point.usage))%")
                    .font(.system(size: 10))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
