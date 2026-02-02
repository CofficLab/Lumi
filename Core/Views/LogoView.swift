import MagicKit
import OSLog
import SwiftUI

struct LogoView: View {
    var body: some View {
        // CoffeeReelIcon constants
        let useDefaultBackground = false
        let handleRotation: Double = 180.0
        let plateColor: Color = .white
        let showBrownCircle: Bool = true
        let cupColor: Color = Color(red: 0.8, green: 0.6, blue: 0.2)

        return GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let plateSize = size * 0.6 // 盘子尺寸略小于整体视图
            let cupSize = plateSize * 0.8
            let brownCircleSize = cupSize * 1
            let redCircleSize = brownCircleSize * 0.5
            let dotSize = redCircleSize * 0.5
            let dotOffset = redCircleSize * 0.5
            let centerDotSize = dotSize * 0.6
            let handleWidth = cupSize * 0.16
            let handleLength = cupSize * 0.7

            ZStack {
                // 背景层：绿色到蓝色的渐变，营造自然清新的感觉
                if useDefaultBackground {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.2, green: 0.5, blue: 0.4),
                            Color(red: 0.2, green: 0.5, blue: 0.7),
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.clear
                }

                // 盘子层：使用遮罩创建带手柄的盘子效果
                Circle()
                    .stroke(plateColor, lineWidth: plateSize - cupSize)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 3)
                    .frame(width: plateSize, height: plateSize)
                    .mask {
                        // 咖啡杯手柄：通过遮罩在盘子边缘创建手柄形状
                        Circle()
                            .stroke(.white, lineWidth: plateSize - cupSize)
                            .frame(width: plateSize, height: plateSize)
                            .overlay {
                                Capsule()
                                    .frame(width: handleLength, height: handleWidth)
                                    .offset(x: cupSize * 0.3)
                                    .rotationEffect(.degrees(handleRotation))
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                                    .blendMode(.destinationOut)
                            }
                    }

                // 咖啡杯层：空心的圆形轮廓，模拟咖啡杯的形状
                Circle()
                    .fill(Color.clear)
                    .stroke(cupColor, lineWidth: cupSize * 0.15)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
                    .frame(width: cupSize, height: cupSize)

                // 装饰层：咖啡色圆形和装饰性圆点
                if showBrownCircle {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.22, blue: 0.17))
                        .frame(width: brownCircleSize, height: brownCircleSize)
                        .mask {
                            Circle()
                                .fill(Color.white)
                                .frame(width: brownCircleSize, height: brownCircleSize)
                                .overlay {
                                    ZStack {
                                        // 四个装饰圆点：通过数学计算均匀分布在圆周上
                                        ForEach(0 ..< 4) { index in
                                            Circle()
                                                .frame(width: dotSize, height: dotSize)
                                                .offset(
                                                    x: dotOffset * cos(Double(index) * .pi / 2),
                                                    y: dotOffset * sin(Double(index) * .pi / 2)
                                                )
                                                .blendMode(.destinationOut)
                                        }
                                        // 中心装饰圆点
                                        Circle()
                                            .frame(width: centerDotSize, height: centerDotSize)
                                            .blendMode(.destinationOut)
                                    }
                                }
                        }
                }
            }
        }
    }
}

#Preview("LogoView") {
    ScrollView {
        LogoView()
            .frame(width: 250, height: 250)
            .shadow2xl()

        LogoView()
            .background(.blue.opacity(0.2))
            .frame(width: 250, height: 250)
            .roundedFull()
    }
    .frame(height: 600)
}

#Preview("LogoView - Snapshot") {
    LogoView()
        .background(LinearGradient.summer)
        .inMagicContainer(.init(width: 500, height: 500), scale: 1)
}
