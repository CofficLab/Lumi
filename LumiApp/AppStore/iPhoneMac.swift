import SwiftUI

struct iPhoneMac: View {
    var body: some View {
        ZStack {
            // 简化背景
            LinearGradient(
                colors: [Color.orange.opacity(0.2), Color.pink.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("SwiftUI Template")
                    .bold()
                    .font(.system(size: 40, design: .rounded))

                Text("macOS 上也精彩")
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

#Preview("App Store iPhone Mac") {
    iPhoneMac()
        .frame(width: 400, height: 700)
}
