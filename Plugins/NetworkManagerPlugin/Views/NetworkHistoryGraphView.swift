import SwiftUI
import MagicKit

struct NetworkHistoryGraphView: View {
    let dataPoints: [NetworkDataPoint]
    let timeRange: TimeRange
    
    @State private var hoverLocation: CGPoint?
    @State private var hoverDataPoint: NetworkDataPoint?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background grid lines (optional, keep simple for now)
                
                if !dataPoints.isEmpty {
                    // Download Graph (Green)
                    GraphArea(data: dataPoints.map { $0.downloadSpeed }, maxValue: maxValue)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.5), Color.green.opacity(0.1)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    GraphLine(data: dataPoints.map { $0.downloadSpeed }, maxValue: maxValue)
                        .stroke(Color.green, lineWidth: 1.5)
                    
                    // Upload Graph (Red)
                    GraphArea(data: dataPoints.map { $0.uploadSpeed }, maxValue: maxValue)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.red.opacity(0.5), Color.red.opacity(0.1)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    GraphLine(data: dataPoints.map { $0.uploadSpeed }, maxValue: maxValue)
                        .stroke(Color.red, lineWidth: 1.5)
                } else {
                    Text("收集数据中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Hover Overlay
                if let hoverLocation = hoverLocation, let point = hoverDataPoint {
                    // Vertical Line
                    Path { path in
                        path.move(to: CGPoint(x: hoverLocation.x, y: 0))
                        path.addLine(to: CGPoint(x: hoverLocation.x, y: geometry.size.height))
                    }
                    .stroke(Color.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
                    // Info Tooltip
                    TooltipView(point: point, timeRange: timeRange)
                        .position(x: clampedX(hoverLocation.x, width: geometry.size.width), y: 40)
                }
            }
            .background(Color.black.opacity(0.01)) // Transparent hit testing
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
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text(formatSpeed(Int64(point.downloadSpeed)))
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }
                
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text(formatSpeed(Int64(point.uploadSpeed)))
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }
            }
        }
        .padding(8)
        .background(VisualEffectBlur(material: .popover, blendingMode: .withinWindow))
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
    
    private func formatSpeed(_ bytesPerSecond: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .memory
        let formatted = formatter.string(fromByteCount: bytesPerSecond)
        
        if formatted.contains("KB") {
            return formatted.replacingOccurrences(of: " KB", with: "K")
        } else if formatted.contains("MB") {
            return formatted.replacingOccurrences(of: " MB", with: "M")
        } else if formatted.contains("GB") {
            return formatted.replacingOccurrences(of: " GB", with: "G")
        }
        return formatted
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
