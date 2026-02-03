import SwiftUI
import Combine

struct CPUHistoryGraphView: View {
    let dataPoints: [CPUDataPoint]
    let timeRange: CPUTimeRange
    
    @State private var hoverLocation: CGPoint?
    @State private var hoverDataPoint: CPUDataPoint?
    
    // Y-axis max value logic
    private var maxValue: Double {
        // CPU usage is 0-100%
        return 100.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if !dataPoints.isEmpty {
                    // Usage Area
                    CPUGraphArea(data: dataPoints.map { $0.usage }, maxValue: maxValue)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.5), Color.blue.opacity(0.1)]), startPoint: .top, endPoint: .bottom))
                    
                    // Usage Line
                    CPUGraphLine(data: dataPoints.map { $0.usage }, maxValue: maxValue)
                        .stroke(Color.blue, lineWidth: 1.5)
                } else {
                    Text("收集数据中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Hover Interaction
                if let hoverLocation = hoverLocation, let point = hoverDataPoint {
                    // Vertical Line
                    Path { path in
                        path.move(to: CGPoint(x: hoverLocation.x, y: 0))
                        path.addLine(to: CGPoint(x: hoverLocation.x, y: geometry.size.height))
                    }
                    .stroke(Color.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
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
                .foregroundColor(.primary)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                Text("\(Int(point.usage))%")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(6)
        .background(VisualEffectBlur(material: .popover, blendingMode: .withinWindow))
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
