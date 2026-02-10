import SwiftUI

struct AppStoreHero: View {
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Text("SwiftUI Template")
                    .asPosterTitle()

                Text("现代化的 SwiftUI 应用模板")
                    .asPosterSubTitle()
            }

            Spacer()

            // 简化的应用预览（带 3D 旋转效果）
            ZStack {
                // 背景
                ContentLayout()
                    .inRootView()
                    .frame(width: 600, height: 300)
                    .background(Color(.windowBackgroundColor))
                    .cornerRadius(12)
                    .rotation3DEffect(
                        .degrees(-8),
                        axis: (x: 0, y: 0, z: 1),
                        anchor: .bottomLeading,
                        perspective: 1.0
                    )
                    .offset(x: -60, y: -20)
                    .shadow(radius: 5)

                // 前景
                ContentLayout()
                    .inRootView()
                    .frame(width: 600, height: 300)
                    .background(Color(.windowBackgroundColor).opacity(0.9))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .rotation3DEffect(
                        .degrees(8),
                        axis: (x: 0, y: 0, z: 1),
                        anchor: .bottomLeading,
                        perspective: 1.0
                    )
                    .offset(x: 10, y: -20)
            }

            Spacer(minLength: 60)
        }
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store Hero") {
    AppStoreHero()
        .inMagicContainer(.macBook13, scale: 0.5)
}
