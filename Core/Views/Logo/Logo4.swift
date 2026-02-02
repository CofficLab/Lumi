import MagicKit
import SwiftUI

/// 方案四：字母变形主题
/// 概念：字母 "L" 的艺术化变形
struct Logo4: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                // 背景光晕
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: size, height: size)
                
                // L 形状
                Path { path in
                    let w = size * 0.6
                    let h = size * 0.7
                    let x = (size - w) / 2
                    let y = (size - h) / 2
                    let thickness = size * 0.15
                    
                    // 竖笔画
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x, y: y + h - thickness))
                    // 圆角连接
                    path.addArc(center: CGPoint(x: x + thickness, y: y + h - thickness), radius: thickness, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
                    
                    // 横笔画
                    path.addLine(to: CGPoint(x: x + w, y: y + h))
                    path.addLine(to: CGPoint(x: x + w, y: y + h - thickness))
                    path.addLine(to: CGPoint(x: x + thickness, y: y + h - thickness))
                    path.addLine(to: CGPoint(x: x + thickness, y: y))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .top,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .blue.opacity(0.5), radius: 5, x: 2, y: 2)
            }
        }
    }
}

#Preview("Logo4 - Letter Deformation") {
    Logo4()
        .frame(width: 200, height: 200)
}
