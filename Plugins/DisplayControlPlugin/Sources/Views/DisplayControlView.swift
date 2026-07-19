import LumiUI
import SwiftUI

// MARK: - Main View

struct DisplayControlView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme
    @StateObject private var service = DisplayService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                AppCard {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(theme.primary.opacity(0.1))
                                .frame(width: 60, height: 60)

                            Image(systemName: "display")
                                .font(.largeTitle)
                                .foregroundStyle(theme.primary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: L("Display Control"))
                                .font(.title.weight(.semibold))
                                .foregroundColor(theme.textPrimary)
                            Text(verbatim: L("Brightness, Volume & Contrast"))
                                .font(.body)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()
                    }
                }

                if service.displays.isEmpty {
                    emptyState
                } else {
                    displaysList
                    restoreDefaultsCard
                }
            }
            .padding()
        }
        .onAppear {
            service.refresh()
        }
    }

    private var emptyState: some View {
        AppCard {
            VStack(spacing: 12) {
                Image(systemName: "display.trianglebadge.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.textSecondary)
                Text(verbatim: L("No displays detected"))
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
                Text(verbatim: L("Connect an external display or check your display connections."))
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private var displaysList: some View {
        VStack(spacing: 16) {
            ForEach(service.displays) { display in
                DisplayControlCard(display: display, service: service)
            }
        }
    }

    private var restoreDefaultsCard: some View {
        AppCard {
            HStack {
                Text(verbatim: L("Restore Defaults"))
                    .font(.body.weight(.medium))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                AppButton(
                    L("Restore"),
                    style: .secondary,
                    action: { service.restoreDefaults() }
                )
                .frame(width: 100)
            }
        }
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module, locale: locale)
    }
}

// MARK: - Display Control Card

struct DisplayControlCard: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme
    let display: ControlledDisplay
    @ObservedObject var service: DisplayService

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: display.isBuiltIn ? "laptopcomputer" : "desktopcomputer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.primary)

                    Text(display.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Text(verbatim: display.isBuiltIn ? L("Built-in") : L("External"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(theme.primary.opacity(0.1)))
                }

                GlassDivider()

                // Control sliders
                VStack(spacing: 10) {
                    controlSlider(for: .brightness)
                    controlSlider(for: .volume)
                    controlSlider(for: .contrast)
                }
            }
        }
    }

    @ViewBuilder
    private func controlSlider(for control: DisplayControlKind) -> some View {
        let isEnabled = display.supports(control)
        let currentValue = service.value(for: control, displayID: display.id)

        HStack(spacing: 12) {
            Image(systemName: control.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isEnabled ? theme.primary : theme.textTertiary)
                .frame(width: 18)

            Text(verbatim: control.label(locale: locale))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isEnabled ? theme.textPrimary : theme.textTertiary)
                .frame(width: 64, alignment: .leading)

            Slider(
                value: Binding(
                    get: { currentValue },
                    set: { service.setValue($0, for: control, displayID: display.id) }
                ),
                in: 0...100,
                step: 1
            )
            .tint(theme.primary)
            .controlSize(.small)
            .disabled(!isEnabled)

            Text("\(Int(currentValue.rounded()))%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(isEnabled ? theme.textPrimary : theme.textTertiary)
                .frame(width: 40, alignment: .trailing)
        }
        .opacity(isEnabled ? 1 : 0.4)
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module, locale: locale)
    }
}
