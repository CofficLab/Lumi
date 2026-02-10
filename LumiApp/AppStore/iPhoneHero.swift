import SwiftUI

struct iPhoneHero: View {
    var body: some View {
        ZStack {
            // 简化背景
            LinearGradient(
                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("SwiftUI Template")
                    .bold()
                    .font(.system(size: 40, design: .rounded))

                Text("现代化的 SwiftUI 应用模板")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                // 简化的应用预览
                ContentLayout()
                    .inRootView()
                    .frame(width: 300, height: 400)
                    .background(Color(.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 10)

                Spacer()
            }
            .padding(30)
        }
    }
}

// MARK: - Preview

#Preview("App Store iPhone Hero") {
    iPhoneHero()
        .frame(width: 400, height: 700)
}
