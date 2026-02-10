import SwiftUI

struct AppStoreICloud: View {
    var body: some View {
        ZStack {
            // 简化背景
            LinearGradient(
                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                VStack(spacing: 20) {
                    Text("iCloud 云同步")
                        .bold()
                        .font(.system(size: 60, design: .rounded))

                    VStack(spacing: 16) {
                        AppStoreFeatureItem(
                            icon: "icloud",
                            title: "云端同步",
                            description: "音乐库实时同步，随时随地访问"
                        )
                        AppStoreFeatureItem(
                            icon: "ipad.and.iphone",
                            title: "多设备同步",
                            description: "iPhone、iPad、Mac 数据无缝流转"
                        )
                        AppStoreFeatureItem(
                            icon: "shield",
                            title: "安全备份",
                            description: "自动备份到 iCloud，数据永不丢失"
                        )
                        AppStoreFeatureItem(
                            icon: "arrow.clockwise",
                            title: "自动同步",
                            description: "添加或修改后自动同步，无需手动操作"
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

#Preview("App Store iCloud") {
    AppStoreICloud()
        .frame(width: 1200, height: 800)
}
