import SwiftUI

extension View {
    /// 简化的背景容器
    func inPosterContainer() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { geo in
                    ZStack {
                        // 左上角大圆形装饰
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.08), .purple.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: geo.size.width * 0.4, height: geo.size.width * 0.4)
                            .position(x: geo.size.width * 0.15, y: geo.size.height * 0.2)

                        // 右下角大圆形装饰
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.06), .blue.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: geo.size.width * 0.5, height: geo.size.width * 0.5)
                            .position(x: geo.size.width * 0.8, y: geo.size.height * 0.75)

                        // 左下角小圆形装饰
                        Circle()
                            .fill(Color.blue.opacity(0.06))
                            .frame(width: geo.size.width * 0.2, height: geo.size.width * 0.2)
                            .position(x: geo.size.width * 0.2, y: geo.size.height * 0.8)

                        // 右上角小圆形装饰
                        Circle()
                            .fill(Color.purple.opacity(0.06))
                            .frame(width: geo.size.width * 0.15, height: geo.size.width * 0.15)
                            .position(x: geo.size.width * 0.85, y: geo.size.height * 0.15)
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.4),
                        Color.teal.opacity(0.3),
                        Color.mint.opacity(0.2),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(Color.black)
            .colorScheme(.dark)
    }
}

// MARK: - Preview

#Preview("Background Container") {
    Text("Preview")
        .inPosterContainer()
}
