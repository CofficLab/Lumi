import SwiftUI

struct WaveformView: View {
    let data: [Double]
    let color: Color
    var maxVal: Double = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            if data.count > 1 {
                // Area
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    
                    let stepX = width / CGFloat(data.count - 1)
                    
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedValue = value / maxVal
                        let y = height * (1.0 - CGFloat(normalizedValue))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.4), color.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                
                // Line
                Path { path in
                    let stepX = width / CGFloat(data.count - 1)
                    
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedValue = value / maxVal
                        let y = height * (1.0 - CGFloat(normalizedValue))
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 2)
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
