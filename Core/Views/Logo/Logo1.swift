import MagicKit
import SwiftUI

/// 方案一：智能光源主题
/// 概念：灯泡 + AI/科技感，象征"点亮灵感、照亮问题"
struct Logo1: View {
    @State private var isBreathing = false
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let bulbSize = size * 0.7
            
            ZStack {
                // 外层光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.6),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: bulbSize * 0.3,
                            endRadius: size * 0.5
                        )
                    )
                    .scaleEffect(isBreathing ? 1.1 : 1.0)
                    .opacity(isBreathing ? 1.0 : 0.7)
                
                // 灯泡主体
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.yellow, .orange]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: bulbSize, height: bulbSize)
                        
                        // 内部灯丝 (闪电形状)
                        Image(systemName: "bolt.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.white)
                            .frame(width: bulbSize * 0.4)
                            .shadow(color: .white, radius: 5)
                    }
                }
            }
            .frame(width: size, height: size)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
    }
}

#Preview("Logo1 - Smart Light") {
    Logo1()
        .frame(width: 200, height: 200)
        .padding()
        .background(Color.black.opacity(0.8))
}
