import LumiUI
import SwiftUI

struct DisplayMenuBarPopupView: View {
    @Environment(\.locale) private var locale
    @ObservedObject private var viewModel: DisplayControlViewModel

    init(viewModel: DisplayControlViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(verbatim: L("Displays"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(viewModel.displays.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if viewModel.displays.isEmpty {
                Text(verbatim: L("No displays detected"))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .onAppear { viewModel.refresh() }
            } else {
                ForEach(viewModel.displays) { display in
                    menuBarDisplayRow(display: display, viewModel: viewModel)
                }
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private func menuBarDisplayRow(display: ControlledDisplay, viewModel: DisplayControlViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "desktopcomputer")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(display.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }

            // Compact brightness slider
            if display.supports(.brightness) {
                compactSlider(
                    icon: "sun.max",
                    value: Binding(
                        get: { viewModel.value(for: .brightness, displayID: display.id) },
                        set: { viewModel.setValue($0, for: .brightness, displayID: display.id) }
                    )
                )
            }

            // Compact volume slider
            if display.supports(.volume) {
                compactSlider(
                    icon: "speaker.wave.2",
                    value: Binding(
                        get: { viewModel.value(for: .volume, displayID: display.id) },
                        set: { viewModel.setValue($0, for: .volume, displayID: display.id) }
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
                .foregroundStyle(.secondary)
                .frame(width: 12)

            Slider(value: value, in: 0...100, step: 1)
                .controlSize(.mini)

            Text("\(Int(value.wrappedValue.rounded()))%")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module, locale: locale)
    }
}
