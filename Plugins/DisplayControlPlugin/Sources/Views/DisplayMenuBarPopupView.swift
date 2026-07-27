import LumiUI
import SwiftUI

struct DisplayMenuBarPopupView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme
    @StateObject private var service = DisplayService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.primary)
                Text(verbatim: L("Displays"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text("\(service.displays.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
            }

            if service.displays.isEmpty {
                Text(verbatim: L("No displays detected"))
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
                    .onAppear { service.refresh() }
            } else {
                ForEach(service.displays) { display in
                    menuBarDisplayRow(display: display, service: service)
                }
            }
        }
        .onAppear {
            service.refresh()
        }
    }

    @ViewBuilder
    private func menuBarDisplayRow(display: ControlledDisplay, service: DisplayService) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "desktopcomputer")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                Text(display.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
            }

            // Compact brightness slider
            if display.supports(.brightness) {
                compactSlider(
                    icon: "sun.max",
                    value: Binding(
                        get: { service.value(for: .brightness, displayID: display.id) },
                        set: { service.setValue($0, for: .brightness, displayID: display.id) }
                    )
                )
            }

            // Compact volume slider
            if display.supports(.volume) {
                compactSlider(
                    icon: "speaker.wave.2",
                    value: Binding(
                        get: { service.value(for: .volume, displayID: display.id) },
                        set: { service.setValue($0, for: .volume, displayID: display.id) }
                    )
                )
            }
        }
        .padding(.vertical, 2)
    }

    private func compactSlider(icon: String, value: Binding<Double>) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .frame(width: 12)

            Slider(value: value, in: 0...100, step: 1)
                .controlSize(.mini)

            Text("\(Int(value.wrappedValue.rounded()))%")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(theme.textSecondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module, locale: locale)
    }
}
