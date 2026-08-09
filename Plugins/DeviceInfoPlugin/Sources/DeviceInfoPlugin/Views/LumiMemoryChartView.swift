import LumiUI
import SwiftUI

/// Line chart view displaying Lumi's own memory usage over time.
public struct LumiMemoryChartView: View {
    @LumiTheme private var theme

    public let dataPoints: [LumiMemoryDataPoint]

    private var lineColor: Color { theme.primary }
    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.primary.opacity(0.4),
                theme.primary.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public init(dataPoints: [LumiMemoryDataPoint]) {
        self.dataPoints = dataPoints
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chart
            chartContent
                .frame(height: 120)
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if dataPoints.isEmpty {
            emptyState
        } else {
            GeometryReader { geometry in
                ZStack {
                    // Grid lines
                    gridLines(for: geometry.size)

                    // Area fill
                    LumiMemoryGraphArea(data: dataPoints.map { $0.memoryMB }, maxValue: maxYValue)
                        .fill(areaGradient)

                    // Line
                    LumiMemoryGraphLine(data: dataPoints.map { $0.memoryMB }, maxValue: maxYValue)
                        .stroke(lineColor, lineWidth: 1.5)
                }
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text(LumiPluginLocalization.string("Collecting...", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func gridLines(for size: CGSize) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Path { path in
                    let y = size.height * CGFloat(index) / 4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(theme.textTertiary.opacity(0.1), lineWidth: 0.5)
            }
        }
    }

    private var maxYValue: Double {
        let maxMB = dataPoints.map { $0.memoryMB }.max() ?? 100
        // Round up to nice number with 20% headroom
        let rounded = ceil(maxMB / 100) * 100
        return max(100, rounded * 1.2)
    }
}

// MARK: - Graph Shapes

struct LumiMemoryGraphLine: Shape {
    var data: [Double]
    var maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1, maxValue > 0 else { return path }

        let stepX = rect.width / CGFloat(data.count - 1)
        let scaleY = rect.height / CGFloat(maxValue)

        path.move(to: CGPoint(x: 0, y: rect.height - CGFloat(data[0]) * scaleY))
        for index in 1..<data.count {
            path.addLine(to: CGPoint(x: CGFloat(index) * stepX, y: rect.height - CGFloat(data[index]) * scaleY))
        }
        return path
    }
}

struct LumiMemoryGraphArea: Shape {
    var data: [Double]
    var maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1, maxValue > 0 else { return path }

        let stepX = rect.width / CGFloat(data.count - 1)
        let scaleY = rect.height / CGFloat(maxValue)

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height - CGFloat(data[0]) * scaleY))
        for index in 1..<data.count {
            path.addLine(to: CGPoint(x: CGFloat(index) * stepX, y: rect.height - CGFloat(data[index]) * scaleY))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

#Preview("With Data") {
    let sampleData: [LumiMemoryDataPoint] = (0..<60).map { i in
        LumiMemoryDataPoint(
            timestamp: Date().timeIntervalSince1970 - Double(60 - i),
            memoryBytes: UInt64((300 + Int.random(in: -50...100)) * 1024 * 1024)
        )
    }
    return LumiMemoryChartView(dataPoints: sampleData)
        .frame(width: 400, height: 150)
        .padding()
}
