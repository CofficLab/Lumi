import SwiftUI

struct AppStoreMinimal: View {
    var body: some View {
        ZStack {
            // 简化背景
            LinearGradient(
                colors: [Color.green.opacity(0.2), Color.teal.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                VStack(spacing: 20) {
                    Text("极简设计")
                        .bold()
                        .font(.system(size: 60, design: .rounded))

                    VStack(spacing: 16) {
                        AppStoreFeatureItem(
                            icon: "trash",
                            title: "没有广告",
                            description: "纯净体验，专注音乐"
                        )
                        AppStoreFeatureItem(
                            icon: "phone.bubble",
                            title: "没有注册",
                            description: "打开即用，快速上手"
                        )
                        AppStoreFeatureItem(
                            icon: "xmark.circle",
                            title: "没有登录",
                            description: "保护隐私，无需账号"
                        )
                        AppStoreFeatureItem(
                            icon: "info.circle",
                            title: "没有弹窗",
                            description: "简洁界面，无干扰"
                        )
                    }
                    .padding(.top, 20)
                }

                Spacer()

                // 简化的应用预览
                ContentLayout()
                    .inRootView()
                    .frame(width: 800, height: 500)
                    .background(Color(.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 10)

                Spacer(minLength: 60)
            }
            .padding(60)
        }
    }
}

// MARK: - Preview

#Preview("App Store Minimal") {
    AppStoreMinimal()
        .frame(width: 1200, height: 800)
}
