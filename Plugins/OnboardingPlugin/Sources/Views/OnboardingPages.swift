import LumiKernel
import SwiftUI

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

// MARK: - Shared Components

/// A single feature item displayed inside an onboarding page.
struct OnboardingFeature {
    let icon: String
    let title: String
    let description: String
}

/// Shared header section used by onboarding pages.
struct OnboardingPageHeader: View {
    let icon: String
    let gradient: [Color]
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

/// Features list section for onboarding pages.
struct OnboardingFeaturesSection: View {
    let features: [OnboardingFeature]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(features.indices, id: \.self) { index in
                let feature = features[index]
                featureRow(feature, isLast: index == features.count - 1)
            }
        }
    }

    private func featureRow(_ feature: OnboardingFeature, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(14)
            .background(.quinary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !isLast {
                Divider()
                    .opacity(0.3)
            }
        }
    }
}

/// Tip card shown at the bottom of onboarding pages.
struct OnboardingTipView: View {
    let tip: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)

            Text(tip)
                .font(.system(size: 13))
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

// MARK: - Convenience View Builders

@ViewBuilder
func headerSection(
    icon: String,
    gradient: [Color],
    title: String,
    subtitle: String
) -> some View {
    OnboardingPageHeader(
        icon: icon,
        gradient: gradient,
        title: title,
        subtitle: subtitle
    )
}

@ViewBuilder
func featuresSection(_ features: [OnboardingFeature]) -> some View {
    OnboardingFeaturesSection(features: features)
}

@ViewBuilder
func tipCard(_ tip: String) -> some View {
    OnboardingTipView(tip: tip)
}

// MARK: - Preview

#Preview("Welcome Page") {
    OnboardingWelcomePage()
        .padding(32)
        .frame(width: 576)
}
