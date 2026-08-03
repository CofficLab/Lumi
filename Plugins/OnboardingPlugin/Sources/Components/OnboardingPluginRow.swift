import LumiUI
import SwiftUI

struct OnboardingPluginRow: View {
    let name: String
    let icon: String
    let enabled: Bool
    let highlighted: Bool
    let reportsToggleTarget: Bool

    @LumiTheme private var theme

    init(
        name: String,
        icon: String,
        enabled: Bool,
        highlighted: Bool,
        reportsToggleTarget: Bool = false
    ) {
        self.name = name
        self.icon = icon
        self.enabled = enabled
        self.highlighted = highlighted
        self.reportsToggleTarget = reportsToggleTarget
    }

    var body: some View {
        AppListRow(isSelected: highlighted) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.appBody)
                    .foregroundStyle(highlighted ? theme.primary : theme.textSecondary)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(name)
                        .font(.appBody)
                }

                Spacer()

                Toggle(text("Enable"), isOn: .constant(enabled))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .stroke(Color.accentColor.opacity(highlighted ? 0.65 : 0), lineWidth: 1)
                .animation(.easeInOut(duration: 0.45), value: highlighted)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        .overlay {
            if reportsToggleTarget {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: OnboardingTargetPreferenceKey.self,
                        value: [
                            .pluginToggle: CGPoint(
                                x: proxy.frame(in: .named("onboardingCanvas")).maxX - 28,
                                y: proxy.frame(in: .named("onboardingCanvas")).midY
                            ),
                        ]
                    )
                }
            }
        }
    }

    private func text(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview("Plugin Row") {
    VStack(spacing: 8) {
        OnboardingPluginRow(name: "Git", icon: "arrow.triangle.branch", enabled: false, highlighted: true)
        OnboardingPluginRow(name: "Project Files", icon: "doc.text", enabled: true, highlighted: false)
    }
    .padding()
    .frame(width: 360)
}
