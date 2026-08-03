import LumiUI
import LumiKernel
import SwiftUI

// MARK: - Empty View

/// Empty state view shown on the "Installed" tab when no Homebrew
/// packages are installed.
///
/// Displays a friendly illustration, short guidance text, and a
/// primary call-to-action that lets the user jump straight to the
/// search tab to discover packages.
struct BrewManagerEmptyView: View {
    /// Called when the user taps the primary CTA.
    ///
    /// The parent typically uses this to switch the selected tab
    /// to the search tab.
    let onBrowsePackages: () -> Void

    /// Optional secondary action (e.g. run a diagnostic or open docs).
    ///
    /// When `nil` the secondary button is hidden.
    var onLearnMore: (() -> Void)? = nil

    @LumiTheme private var theme

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            content
                .padding(.horizontal, 32)
                .padding(.vertical, 24)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var content: some View {
        AppCard(
            style: .subtle,
            cornerRadius: 20,
            padding: EdgeInsets(top: 32, leading: 28, bottom: 32, trailing: 28)
        ) {
            VStack(spacing: 20) {
                iconBadge

                VStack(spacing: 8) {
                    Text(LumiPluginLocalization.string("No packages installed", bundle: .module))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    AppButton(
                        LumiPluginLocalization.string("Browse Packages", bundle: .module),
                        systemImage: "magnifyingglass",
                        style: .primary,
                        fillsWidth: true
                    ) {
                        onBrowsePackages()
                    }

                    if let onLearnMore {
                        AppButton(
                            LumiPluginLocalization.string("Learn More", bundle: .module),
                            systemImage: "book",
                            style: .ghost,
                            fillsWidth: true,
                            action: onLearnMore
                        )
                    }
                }
            }
            .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
    }

    /// Rounded gradient badge hosting the SF Symbol illustration.
    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.primary.opacity(0.18),
                            theme.primary.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "shippingbox")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(theme.primary)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)
    }

    /// Two-line, localized description for users who just opened
    /// the plugin and have not installed anything yet.
    private var description: String {
        LumiPluginLocalization.string(
            "Search the Homebrew repository to install your first formula or cask, then come back here to manage updates and uninstalls.",
            bundle: .module
        )
    }
}

// MARK: - Preview

#Preview("Installed · Light") {
    BrewManagerEmptyView(
        onBrowsePackages: {},
        onLearnMore: {}
    )
    .frame(width: 480, height: 480)
}

#Preview("Installed · CTA only") {
    BrewManagerEmptyView(onBrowsePackages: {})
        .frame(width: 480, height: 480)
}

#Preview("Installed · Dark") {
    BrewManagerEmptyView(
        onBrowsePackages: {},
        onLearnMore: {}
    )
    .frame(width: 480, height: 480)
    .environment(\.colorScheme, .dark)
}
