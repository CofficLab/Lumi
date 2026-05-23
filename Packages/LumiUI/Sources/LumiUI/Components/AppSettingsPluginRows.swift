import SwiftUI

// MARK: - Plugin Toggle Row

/// Settings row with icon, title, description, and trailing toggle.
public struct AppSettingsPluginToggleRow: View {
    @LumiTheme private var theme

    private let name: String
    private let description: String
    private let icon: String
    @Binding private var isEnabled: Bool

    public init(
        name: String,
        description: String,
        icon: String,
        isEnabled: Binding<Bool>
    ) {
        self.name = name
        self.description = description
        self.icon = icon
        self._isEnabled = isEnabled
    }

    public var body: some View {
        AppSettingsRow {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.appTitle)
                    .foregroundColor(theme.primary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(theme.appAccentSoftFill)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)

                    Text(description)
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)
                }

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
        }
    }
}

// MARK: - Mini Progress Ring

/// Compact circular progress indicator for enabled/total ratios.
public struct AppMiniProgressRing: View {
    @LumiTheme private var theme

    private let total: Int
    private let enabled: Int

    public init(total: Int, enabled: Int) {
        self.total = total
        self.enabled = enabled
    }

    private var ratio: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(enabled) / CGFloat(total)
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(theme.appStatusMutedFill, lineWidth: 3)

            Circle()
                .trim(from: 0, to: ratio)
                .stroke(theme.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(ratio * 100))%")
                .font(.appMicroEmphasized)
                .foregroundColor(theme.primary)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Stats Bar

/// Footer stats strip for settings list pages.
public struct AppSettingsStatsBar: View {
    @LumiTheme private var theme

    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        HStack {
            Spacer()

            Text(text)
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 24)
        .background(.bar)
    }
}
