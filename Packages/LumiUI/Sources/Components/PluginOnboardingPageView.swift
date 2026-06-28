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
                    .padding(.top, AppUI.Spacing.lg)
            }

            Spacer(minLength: 0)

            if let tip {
                tipCard(tip)
                    .padding(.top, AppUI.Spacing.lg)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AppUISpacing.headerSpacing) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(AppUI.Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    // MARK: - Features

    private var featuresList: some View {
        VStack(spacing: AppUI.Spacing.sm) {
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quinary.opacity(0.5))
                    .frame(width: 36, height: 36)

                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(feature.description)
                    .font(AppUI.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(.quinary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Tip

    private func tipCard(_ tip: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)

            Text(tip)
                .font(AppUI.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.yellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.yellow.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private enum AppUISpacing {
    static let headerSpacing: CGFloat = 20
}

// MARK: - Preview

#Preview("Plugin Onboarding Page") {
    PluginOnboardingPageView(
        icon: "terminal",
        displayName: "Terminal",
        description: "Native interactive terminal powered by SwiftTerm",
        features: [
            .init(icon: "rectangle.3.group", title: "Multiple tabs", description: "Open several sessions side by side"),
            .init(icon: "keyboard", title: "Full keyboard", description: "Complete VT escapes and shell integration"),
        ],
        tip: "Open it from the sidebar at any time."
    )
    .padding(32)
    .frame(width: 576)
}

#Preview("Minimal") {
    PluginOnboardingPageView(
        icon: "info.circle",
        displayName: "Device Info",
        description: "Shows basic device and system information."
    )
    .padding(32)
    .frame(width: 576)
}
