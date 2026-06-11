import LumiUI
import SwiftUI

// MARK: - Main View

struct DisplayControlView: View {
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
                            Text("Display Control", bundle: .module)
                                .font(.title.weight(.semibold))
                                .foregroundColor(theme.textPrimary)
                            Text("Brightness, Volume & Contrast", bundle: .module)
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
                Text("No displays detected", bundle: .module)
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
                Text("Connect an external display or check your display connections.", bundle: .module)
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
}

// MARK: - Display Control Card

struct DisplayControlCard: View {
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

                    Text(display.isBuiltIn ? String(localized: "Built-in", bundle: .module) : String(localized: "External", bundle: .module))
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

            Text(control.label)
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
}
