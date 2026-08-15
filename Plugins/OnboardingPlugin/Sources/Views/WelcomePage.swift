import SwiftUI

/// Onboarding welcome page shown on first launch.
public struct WelcomePage: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection(
                icon: "sparkles",
                gradient: welcomeGradient,
                title: LumiPluginLocalization.string("Welcome to Lumi", bundle: .module),
                subtitle: LumiPluginLocalization.string("Your AI-powered personal desktop assistant", bundle: .module)
            )

            featuresSection(welcomeFeatures)
                .padding(.top, 28)

            // 轻量提示：项目是可选功能，不作为引导步骤强制用户配置
            Text(LumiPluginLocalization.string("Optional: add a project later from the title bar to give the agent file context.", bundle: .module))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 20)

            Spacer(minLength: 0)
        }
    }

    private var welcomeGradient: [Color] {
        [.blue, .purple]
    }

    private var welcomeFeatures: [Feature] {
        [
            Feature(
                icon: "brain",
                title: LumiPluginLocalization.string("Smart Conversations", bundle: .module),
                description: LumiPluginLocalization.string("Support for local and cloud LLMs, intelligently handling complex tasks", bundle: .module)
            ),
            Feature(
                icon: "hammer.circle",
                title: LumiPluginLocalization.string("Agent Capabilities", bundle: .module),
                description: LumiPluginLocalization.string("Automatically execute file operations, command line, Git and other tasks", bundle: .module)
            ),
            Feature(
                icon: "rectangle.3.group",
                title: LumiPluginLocalization.string("Parallel Sessions", bundle: .module),
                description: LumiPluginLocalization.string("Process multiple independent tasks in parallel without interference", bundle: .module)
            ),
        ]
    }
}

// MARK: - Preview

#Preview("Welcome Page") {
    WelcomePage()
        .padding(32)
        .frame(width: 576)
}
