import SwiftUI

struct FeaturesPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(
                icon: "map.fill",
                gradient: [.green, .blue],
                title: OnboardingPageLocalization.string("A quick tour"),
                subtitle: OnboardingPageLocalization.string("Lumi brings conversations, coding, and desktop tools together in one workspace.")
            )

            featuresSection([
                Feature(icon: "bubble.left.and.bubble.right.fill", title: OnboardingPageLocalization.string("Chat"), description: OnboardingPageLocalization.string("Ask questions, write drafts, and run agent tasks from the chat workspace.")),
                Feature(icon: "chevron.left.forwardslash.chevron.right", title: OnboardingPageLocalization.string("Editor"), description: OnboardingPageLocalization.string("Open a project and work with files alongside your conversations.")),
                Feature(icon: "gearshape.2.fill", title: OnboardingPageLocalization.string("Desktop tools"), description: OnboardingPageLocalization.string("Discover system tools and plugins from the ActivityBar and settings."))
            ])
            .padding(.top, 24)
        }
    }
}
