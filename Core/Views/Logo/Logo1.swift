import MagicKit
import SwiftUI

/// 方案一：智能光源主题
/// 概念：灯泡 + AI/科技感，象征"点亮灵感、照亮问题"
struct Logo1: View {
    /// 是否使用单色模式（适用于状态栏等需要黑白显示的场景）
    var isMonochrome: Bool = false
    /// 是否禁用呼吸动画（适用于静态图标）
    var disableAnimation: Bool = false

    @State private var isBreathing = false

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let bulbSize = size * 0.9
            
            ZStack {
                // 外层光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                isMonochrome ? Color.white.opacity(0.99) : Color.orange.opacity(0.6),
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
                                    gradient: Gradient(colors: isMonochrome ? [Color.white, Color.white.opacity(0.9)] : [.yellow, .orange]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: bulbSize, height: bulbSize)

                        // 内部灯丝 (闪电形状)
                        Image(systemName: "bolt.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(isMonochrome ? .black : .white)
                            .frame(width: bulbSize * 0.4)
                            .shadow(color: isMonochrome ? .clear : .white, radius: 5)
                    }
                }
            }
            .frame(width: size, height: size)
            .onAppear {
                if !disableAnimation {
                    withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isBreathing = true
                    }
                }
            }
        }
    }
}

#Preview("Logo1 - Smart Light") {
    VStack(spacing: 30) {
        // 彩色模式
        Logo1()
            .frame(width: 200, height: 200)
            .padding()
            .background(Color.black.opacity(0.8))

        // 单色模式（状态栏适用）
        HStack(spacing: 20) {
            Logo1(isMonochrome: true, disableAnimation: true)
                .frame(width: 40, height: 40)
                .background(Color.black)

            Logo1(isMonochrome: true, disableAnimation: true)
                .frame(width: 40, height: 40)
                .background(Color.white)
        }
        .padding()
    }
}
