// MARK: - OnboardingWelcomePage

/// Onboarding welcome page shown on first launch.
public struct OnboardingWelcomePage: View {
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

            Spacer(minLength: 0)
        }
    }

    private var welcomeGradient: [Color] {
        [.blue, .purple]
    }

    private var welcomeFeatures: [OnboardingFeature] {
        [
            OnboardingFeature(
                icon: "brain",
                title: LumiPluginLocalization.string("Smart Conversations", bundle: .module),
                description: LumiPluginLocalization.string("Support for local and cloud LLMs, intelligently handling complex tasks", bundle: .module)
            ),
            OnboardingFeature(
                icon: "hammer.circle",
                title: LumiPluginLocalization.string("Agent Capabilities", bundle: .module),
                description: LumiPluginLocalization.string("Automatically execute file operations, command line, Git and other tasks", bundle: .module)
            ),
            OnboardingFeature(
                icon: "rectangle.3.group",
                title: LumiPluginLocalization.string("Parallel Sessions", bundle: .module),
                description: LumiPluginLocalization.string("Process multiple independent tasks in parallel without interference", bundle: .module)
            ),
        ]
    }
}
