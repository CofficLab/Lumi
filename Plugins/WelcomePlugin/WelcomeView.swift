import SwiftUI

/// 欢迎视图：显示应用欢迎界面和使用指南
struct WelcomeView: View {
    @EnvironmentObject var app: AppProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // 主要欢迎内容
                welcomeSection

                Spacer()
            }
            .padding(40)
            .infinite()
        }
    }

    // MARK: - 欢迎区域

    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: WelcomePlugin.iconName)
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("欢迎使用 Lumi")
                .font(.title)
                .fontWeight(.bold)

            Text("简洁高效的助理软件")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Preview

#Preview("Welcome View") {
    WelcomeView()
        .withDebugBar()
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
