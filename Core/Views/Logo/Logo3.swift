import MagicKit
import SwiftUI

/// 方案三：多功能聚合主题
/// 概念：模块化工具箱，象征"功能集成"
struct Logo3: View {
    @State private var activeIndex = 0
    let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let iconSize = size * 0.35
            
            ZStack {
                // 六边形背景
                HexagonShape()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(radius: 5)
                
                // 内部图标网格
                VStack(spacing: 5) {
                    HStack(spacing: 15) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: iconSize * 0.6))
                            .opacity(activeIndex == 0 ? 1.0 : 0.4)
                            .scaleEffect(activeIndex == 0 ? 1.2 : 1.0)
                        
                        Image(systemName: "wrench.fill")
                            .font(.system(size: iconSize * 0.6))
                            .opacity(activeIndex == 1 ? 1.0 : 0.4)
                            .scaleEffect(activeIndex == 1 ? 1.2 : 1.0)
                    }
                    HStack(spacing: 15) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: iconSize * 0.6))
                            .opacity(activeIndex == 2 ? 1.0 : 0.4)
                            .scaleEffect(activeIndex == 2 ? 1.2 : 1.0)
                        
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: iconSize * 0.6))
                            .opacity(activeIndex == 3 ? 1.0 : 0.4)
                            .scaleEffect(activeIndex == 3 ? 1.2 : 1.0)
                    }
                }
                .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut) {
                activeIndex = (activeIndex + 1) % 4
            }
        }
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let x = rect.midX
        let y = rect.midY
        let side = min(width, height) / 2
        
        // 六边形顶点计算
        let angle = CGFloat.pi / 3
        
        path.move(to: CGPoint(x: x + side * cos(0), y: y + side * sin(0)))
        for i in 1..<6 {
            path.addLine(to: CGPoint(x: x + side * cos(angle * CGFloat(i)), y: y + side * sin(angle * CGFloat(i))))
        }
        path.closeSubpath()
        return path
    }
}

#Preview("Logo3 - Multi-function") {
    Logo3()
        .frame(width: 200, height: 200)
}
