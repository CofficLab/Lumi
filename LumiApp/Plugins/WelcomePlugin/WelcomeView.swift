import SwiftUI

/// Welcome View: Displays the app's welcome interface and user guide
struct WelcomeView: View {
    @EnvironmentObject var app: AppProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // Main welcome content
                welcomeSection

                Spacer()
            }
            .padding(40)
            .infinite()
        }
        .navigationTitle("")
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: WelcomePlugin.iconName)
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundStyle(DesignTokens.Color.gradients.auroraGradient)

            Text("Welcome to Lumi")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text("A simple and efficient assistant app")
                .font(.body)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
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
