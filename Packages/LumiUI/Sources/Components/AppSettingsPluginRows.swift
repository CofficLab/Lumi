import SwiftUI

// MARK: - Plugin Toggle Row

/// Settings row with icon, title, description, and trailing toggle.
public struct AppSettingsPluginToggleRow: View {
    @LumiTheme private var theme

    private let name: String
    private let description: String
    private let icon: String
    private let posterViews: [AnyView]
    @Binding private var isEnabled: Bool
    private let posterHeight: CGFloat = 280
    @State private var selectedPosterIndex = 0

    public init(
        name: String,
        description: String,
        icon: String,
        posterViews: [AnyView] = [],
        isEnabled: Binding<Bool>
    ) {
        self.name = name
        self.description = description
        self.icon = icon
        self.posterViews = posterViews
        self._isEnabled = isEnabled
    }

    public var body: some View {
        AppCard(
            style: .elevated,
            cornerRadius: 8,
            padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
            showShadow: true,
            shadowIntensity: 0.55
        ) {
            VStack(alignment: .leading, spacing: 0) {
                posterArea

                pluginMetadata
            }
        }
    }

    @ViewBuilder
    private var posterArea: some View {
        if posterViews.isEmpty {
            posterFrame(AnyView(defaultPoster))
                .frame(maxWidth: .infinity)
                .frame(height: posterHeight)
        } else if posterViews.count == 1, let posterView = posterViews.first {
            posterFrame(posterView)
                .frame(maxWidth: .infinity)
                .frame(height: posterHeight)
        } else {
            ZStack(alignment: .bottom) {
                posterFrame(posterViews[normalizedPosterIndex])
                    .frame(maxWidth: .infinity)
                    .frame(height: posterHeight)

                HStack(spacing: 8) {
                    carouselButton(systemImage: "chevron.left") {
                        selectPoster(offset: -1)
                    }

                    HStack(spacing: 5) {
                        ForEach(posterViews.indices, id: \.self) { index in
                            Circle()
                                .fill(index == normalizedPosterIndex ? theme.primary : theme.textTertiary.opacity(0.35))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(theme.appPanelBackground.opacity(0.82)))

                    carouselButton(systemImage: "chevron.right") {
                        selectPoster(offset: 1)
                    }
                }
                .padding(.bottom, 22)
            }
        }
    }

    private var normalizedPosterIndex: Int {
        guard !posterViews.isEmpty else { return 0 }
        return min(max(selectedPosterIndex, 0), posterViews.count - 1)
    }

    private func selectPoster(offset: Int) {
        guard !posterViews.isEmpty else { return }
        let nextIndex = (normalizedPosterIndex + offset + posterViews.count) % posterViews.count
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedPosterIndex = nextIndex
        }
    }

    private func carouselButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.appPanelBackground.opacity(0.82)))
        }
        .buttonStyle(.plain)
    }

    private func posterFrame(_ posterView: AnyView) -> some View {
        posterView
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.appDivider, lineWidth: 1)
            )
            .padding(16)
    }

    private var defaultPoster: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    theme.primary.opacity(0.16),
                    theme.primarySecondary.opacity(0.08),
                    theme.appPanelBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(alignment: .top, spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(theme.primary)
                    .frame(width: 84, height: 84)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.appAccentSoftFill)
                    )

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(name)
                            .font(.appTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)

                        Text(description.isEmpty ? "为 Lumi 增加一项可配置能力" : description)
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        defaultFeaturePill("可配置")
                        defaultFeaturePill(isEnabled ? "当前已启用" : "可按需启用")
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }

    private func defaultFeaturePill(_ title: String) -> some View {
        Text(title)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(theme.appStatusMutedFill))
    }

    private var pluginMetadata: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.appTitle)
                .foregroundColor(theme.primary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.appAccentSoftFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.appDivider, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Text(description)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button {
                isEnabled.toggle()
            } label: {
                Text(isEnabled ? String(localized: "Enabled", bundle: .module) : String(localized: "Enable", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(isEnabled ? theme.textSecondary : theme.primary)
                    .frame(minWidth: 58)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isEnabled ? theme.appStatusMutedFill : theme.appAccentSoftFill)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(theme.appPanelBackground.opacity(0.82))
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

// MARK: - Plugin Poster

public struct AppPluginPosterMetric: Hashable, Sendable {
    public let value: String
    public let label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

public struct AppPluginPosterView: View {
    @LumiTheme private var theme

    private let title: String
    private let subtitle: String
    private let icon: String
    private let accent: Color
    private let metrics: [AppPluginPosterMetric]
    private let rows: [String]
    private let chips: [String]

    public init(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        metrics: [AppPluginPosterMetric] = [],
        rows: [String] = [],
        chips: [String] = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
        self.metrics = metrics
        self.rows = rows
        self.chips = chips
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accent.opacity(0.22),
                    theme.appPanelBackground,
                    theme.appPanelBackground.opacity(0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(accent)
                        .frame(width: 64, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(accent.opacity(0.13))
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.appTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(2)

                        Text(subtitle)
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(3)
                    }

                    if !chips.isEmpty {
                        posterChips
                    }

                    Spacer(minLength: 0)
                }

                VStack(spacing: 10) {
                    if !metrics.isEmpty {
                        metricGrid
                    }

                    if !rows.isEmpty {
                        rowPanel
                    }
                }
                .frame(maxWidth: 245)
            }
            .padding(24)
        }
    }

    private var posterChips: some View {
        HStack(spacing: 6) {
            ForEach(Array(chips.prefix(3)), id: \.self) { chip in
                Text(chip)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(theme.appStatusMutedFill))
            }
        }
    }

    private var metricGrid: some View {
        HStack(spacing: 8) {
            ForEach(metrics, id: \.self) { metric in
                VStack(spacing: 3) {
                    Text(metric.value)
                        .font(.appBodyEmphasized)
                        .foregroundColor(accent)
                        .lineLimit(1)

                    Text(metric.label)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.appPanelBackground.opacity(0.82))
                )
            }
        }
    }

    private var rowPanel: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 9) {
                    Circle()
                        .fill(index == 0 ? accent : theme.textTertiary.opacity(0.35))
                        .frame(width: 7, height: 7)

                    Text(row)
                        .font(.appCaption)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.appPanelBackground.opacity(index == 0 ? 0.94 : 0.64))
                )
            }
        }
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
