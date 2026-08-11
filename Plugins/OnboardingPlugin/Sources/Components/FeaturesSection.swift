import SwiftUI

// MARK: - FeaturesSection

/// Features list section for onboarding pages.
struct FeaturesSection: View {
    let features: [Feature]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(features.indices, id: \.self) { index in
                let feature = features[index]
                featureRow(feature, isLast: index == features.count - 1)
            }
        }
    }

    private func featureRow(_ feature: Feature, isLast: Bool) -> some View {
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

// MARK: - Convenience View Builder

@ViewBuilder
func featuresSection(_ features: [Feature]) -> some View {
    FeaturesSection(features: features)
}

#Preview("Features Section") {
    FeaturesSection(features: [
        Feature(icon: "brain", title: LumiPluginLocalization.string("Smart Conversations", bundle: .module), description: "Support for local and cloud LLMs"),
        Feature(icon: "hammer.circle", title: LumiPluginLocalization.string("Agent Capabilities", bundle: .module), description: "Execute tools and tasks automatically")
    ])
    .padding()
    .frame(width: 520)
}
