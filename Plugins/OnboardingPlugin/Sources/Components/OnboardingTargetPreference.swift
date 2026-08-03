import SwiftUI

enum OnboardingTargetID: Hashable {
    case settings
    case plugins
    case pluginToggle
}

struct OnboardingTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [OnboardingTargetID: CGPoint] = [:]

    static func reduce(
        value: inout [OnboardingTargetID: CGPoint],
        nextValue: () -> [OnboardingTargetID: CGPoint]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func reportsOnboardingTarget(_ id: OnboardingTargetID) -> some View {
        overlay {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OnboardingTargetPreferenceKey.self,
                    value: [
                        id: CGPoint(
                            x: proxy.frame(in: .named("onboardingCanvas")).midX,
                            y: proxy.frame(in: .named("onboardingCanvas")).midY
                        )
                    ]
                )
            }
        }
    }
}
