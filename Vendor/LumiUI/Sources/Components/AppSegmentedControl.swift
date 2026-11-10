import SwiftUI

/// A lightweight segmented control for switching between a fixed set of options.
///
/// Renders as a row of equal-weight segments with the selected segment filled in
/// the theme's primary color. Use it as a drop-in replacement for a native
/// `Picker` configured with `.pickerStyle(.segmented)` when you want the Lumi
/// chrome styling and hover motion.
public struct AppSegmentedControl: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference

    let options: [String]
    let titles: [Text]
    let selection: Binding<Int>
    let maxWidth: CGFloat?

    @State private var hoveredIndex: Int? = nil

    /// Creates a segmented control with plain `String` labels.
    public init(
        _ options: [String],
        selection: Binding<Int>,
        maxWidth: CGFloat? = nil
    ) {
        self.options = options
        self.titles = options.map { Text($0) }
        self.selection = selection
        self.maxWidth = maxWidth
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                segment(at: index)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(theme.textSecondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .stroke(theme.appSubtleBorder, lineWidth: 1)
        )
        .frame(maxWidth: maxWidth)
        .animation(
            AppUI.Motion.enabled(AppUI.Motion.selection, preference: motionPreference),
            value: selection.wrappedValue
        )
    }

    @ViewBuilder
    private func segment(at index: Int) -> some View {
        let isSelected = selection.wrappedValue == index
        let isHovered = hoveredIndex == index && !isSelected

        Button {
            guard selection.wrappedValue != index else { return }
            selection.wrappedValue = index
        } label: {
            titles[index]
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .foregroundStyle(isSelected ? Color.white : theme.textSecondary)
                .background(segmentBackground(isSelected: isSelected, isHovered: isHovered))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(options[index])
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .onHover { hovering in
            guard motionPreference.allowsMotion else {
                hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
                return
            }
            withAnimation(AppUI.Motion.enabled(AppUI.Motion.hover, preference: motionPreference)) {
                hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
            }
        }
    }

    @ViewBuilder
    private func segmentBackground(isSelected: Bool, isHovered: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm - 2, style: .continuous)
                .fill(theme.primary)
        } else if isHovered {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm - 2, style: .continuous)
                .fill(theme.textSecondary.opacity(0.10))
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm - 2, style: .continuous)
                .fill(Color.clear)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AppSegmentedControl(
            ["Distribution", "Xcode Cloud"],
            selection: .constant(0),
            maxWidth: 320
        )

        AppSegmentedControl(
            ["Auto", "Manual"],
            selection: .constant(1)
        )

        AppSegmentedControl(
            ["1h", "6h", "24h", "7d"],
            selection: .constant(2),
            maxWidth: 200
        )
    }
    .padding()
    .frame(width: 360)
    .background(Color.gray.opacity(0.15))
}
