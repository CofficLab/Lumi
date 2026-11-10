import SwiftUI

/// A reusable onboarding page contributed by a plugin.
///
/// Each plugin that registers a view container can return an instance of this
/// view from its `onboardingPages(context:)` contribution so that the app-wide
/// onboarding flow (`OnboardingPlugin`) can present one consistent page per
/// plugin. The header, feature rows, and optional tip card follow the same
/// layout the built-in welcome pages use.
public struct PluginOnboardingPageView: View {
    /// A single feature row displayed inside an onboarding page.
    public struct Feature: Identifiable, Sendable {
        public let id = UUID()
        public let icon: String
        public let title: String
        public let description: String

        public init(icon: String, title: String, description: String) {
            self.icon = icon
            self.title = title
            self.description = description
        }
    }

    private let icon: String
    private let displayName: String
    private let description: String
    private let features: [Feature]
    private let tip: String?

    @LumiTheme private var theme

    /// Creates an onboarding page view.
    /// - Parameters:
    ///   - icon: SF Symbol name shown in the header badge.
    ///   - displayName: Plugin display name, used as the page title.
    ///   - description: One-line summary shown under the title.
    ///   - features: Optional feature rows. Pass an empty array to omit the list.
    ///   - tip: Optional tip card text. Pass `nil` to omit the card.
    public init(
        icon: String,
        displayName: String,
        description: String,
        features: [Feature] = [],
        tip: String? = nil
    ) {
        self.icon = icon
        self.displayName = displayName
        self.description = description
        self.features = features
        self.tip = tip
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !features.isEmpty {
                featuresList
                    .padding(.top, DesignTokens.Spacing.lg)
            }

            Spacer(minLength: 0)

            if let tip {
                tipCard(tip)
                    .padding(.top, DesignTokens.Spacing.lg)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.md + 4) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.primary.opacity(0.15), theme.primary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.primary, theme.primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(DesignTokens.Typography.title1)
                    .foregroundStyle(theme.textPrimary)

                Text(description)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    // MARK: - Features

    private var featuresList: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                featureRow(feature)
                if index < features.count - 1 {
                    Divider().opacity(0.3)
                }
            }
        }
    }

    private func featureRow(_ feature: Feature) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(theme.textSecondary.opacity(0.08))
                    .frame(width: 36, height: 36)

                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(DesignTokens.Typography.bodyEmphasized)
                    .foregroundStyle(theme.textPrimary)

                Text(feature.description)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(theme.textSecondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm + 4, style: .continuous))
    }

    // MARK: - Tip

    private func tipCard(_ tip: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm + 2) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(theme.warning)

            Text(tip)
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(DesignTokens.Spacing.sm + 4)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm + 2, style: .continuous)
                .fill(theme.warning.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm + 2, style: .continuous)
                        .strokeBorder(theme.warning.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview("Plugin Onboarding Page") {
    PluginOnboardingPageView(
        icon: "terminal",
        displayName: "Terminal",
        description: "Native interactive terminal powered by SwiftTerm",
        features: [
            .init(icon: "rectangle.3.group", title: LumiUILocalization.string("Multiple tabs"), description: "Open several sessions side by side"),
            .init(icon: "keyboard", title: LumiUILocalization.string("Full keyboard"), description: "Complete VT escapes and shell integration"),
        ],
        tip: "Open it from the sidebar at any time."
    )
    .padding(DesignTokens.Spacing.xl)
    .frame(width: 576)
}

#Preview("Minimal") {
    PluginOnboardingPageView(
        icon: "info.circle",
        displayName: "Device Info",
        description: "Shows basic device and system information."
    )
    .padding(DesignTokens.Spacing.xl)
    .frame(width: 576)
}
