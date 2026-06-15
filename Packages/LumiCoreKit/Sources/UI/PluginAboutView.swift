import SwiftUI

public struct PluginAboutView: View {
    public struct Feature: Sendable {
        public let icon: String
        public let title: String
        public let description: String

        public init(icon: String, title: String, description: String) {
            self.icon = icon
            self.title = title
            self.description = description
        }
    }

    private let features: [Feature]
    private let steps: [String]
    private let tips: [String]

    public init(features: [Feature], steps: [String] = [], tips: [String] = []) {
        self.features = features
        self.steps = steps
        self.tips = tips
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                    featureRow(feature)
                }

                if !steps.isEmpty {
                    howItWorksCard
                }

                if !tips.isEmpty {
                    tipsCard
                }
            }
            .padding()
        }
    }

    private func featureRow(_ feature: Feature) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 14, weight: .semibold))

                Text(feature.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(cardBackground)
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tint)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                            )

                        Text(step)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tint)
                            .frame(width: 16)

                        Text(tip)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
}

public extension LumiPlugin {
    @MainActor
    static func pluginAboutView(
        features: [PluginAboutView.Feature],
        steps: [String] = [],
        tips: [String] = []
    ) -> AnyView {
        AnyView(PluginAboutView(features: features, steps: steps, tips: tips))
    }
}
