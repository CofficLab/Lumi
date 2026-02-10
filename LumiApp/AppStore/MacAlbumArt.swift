import SwiftUI

struct AppStoreAlbumArt: View {
    var body: some View {
        ZStack {
            // 简化背景
            LinearGradient(
                colors: [Color.cyan.opacity(0.2), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                VStack(spacing: 20) {
                    Text("专辑封面")
                        .asPosterTitle()

                    VStack(spacing: 16) {
                        AppStoreFeatureItem(
                            icon: "photo.fill",
                            title: "高清封面",
                            description: "自动获取专辑封面，无需手动添加"
                        )
                    }
                    .padding(.top, 20)
                }

                Spacer()

                // 简化的应用预览（带 3D 旋转效果）
                ZStack {
                    // 背景
                    ContentLayout()
                        .inRootView()
                        .frame(width: 800, height: 500)
                        .background(Color(.windowBackgroundColor))
                        .cornerRadius(12)
                        .rotation3DEffect(
                            .degrees(-3),
                            axis: (x: 0, y: 0, z: 1),
                            anchor: .bottomLeading,
                            perspective: 1.0
                        )
                        .offset(x: -60, y: -20)
                        .shadow(radius: 5)

                    // 前景
                    ContentLayout()
                        .inRootView()
                        .frame(width: 800, height: 500)
                        .background(Color(.windowBackgroundColor).opacity(0.9))
                        .cornerRadius(12)
                        .shadow(radius: 20)
                        .rotation3DEffect(
                            .degrees(3),
                            axis: (x: 0, y: 0, z: 1),
                            anchor: .bottomLeading,
                            perspective: 1.0
                        )
                        .offset(x: 10, y: -20)
                }

                Spacer(minLength: 60)
            }
            .padding(60)
        }
    }
}

// MARK: - Preview

#Preview("App Store Album Art") {
    AppStoreAlbumArt()
        .frame(width: 1200, height: 800)
}
