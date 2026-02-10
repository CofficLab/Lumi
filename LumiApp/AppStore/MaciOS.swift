import SwiftUI

struct AppStoreiOS: View {
    var body: some View {
        ZStack {
            // 简化背景
            LinearGradient(
                colors: [Color.orange.opacity(0.2), Color.pink.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Text("iOS 完美适配")
                    .bold()
                    .font(.system(size: 60, design: .rounded))
                    .offset(x: 60, y: -20)

                Spacer()

                // 简化的设备预览
                HStack(spacing: 40) {
                    // iPad 预览
                    ContentLayout()
                        .inRootView()
                        .frame(width: 400, height: 550)
                        .background(Color(.windowBackgroundColor))
                        .cornerRadius(16)
                        .rotation3DEffect(
                            .degrees(-8),
                            axis: (x: 0, y: 0, z: 1),
                            anchor: .bottomLeading,
                            perspective: 1.0
                        )
                        .offset(x: -60, y: 0)
                        .shadow(radius: 10)

                    // iPhone 预览
                    ContentLayout()
                        .inRootView()
                        .frame(width: 300, height: 600)
                        .background(Color(.windowBackgroundColor))
                        .cornerRadius(20)
                        .rotation3DEffect(
                            .degrees(4),
                            axis: (x: 0, y: 0, z: 1),
                            anchor: .bottomLeading,
                            perspective: 1.0
                        )
                        .offset(x: 80, y: -20)
                        .shadow(radius: 15)
                }

                Spacer(minLength: 60)
            }
            .padding(60)
        }
    }
}

// MARK: - Preview

#Preview("App Store iOS") {
    AppStoreiOS()
        .frame(width: 1200, height: 800)
}
