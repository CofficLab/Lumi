import SwiftUI
#if os(macOS)
import AppKit
#endif

/// HTML/CSS 内联颜色选择器。
public struct ColorPickerInlineView: View {
    @Binding var color: Color
    public let label: String
    public let onCommit: (String) -> Void

    public init(
        color: Binding<Color>,
        label: String = "Color",
        onCommit: @escaping (String) -> Void = { _ in }
    ) {
        self._color = color
        self.label = label
        self.onCommit = onCommit
    }

    public var body: some View {
        ColorPicker(label, selection: $color, supportsOpacity: true)
            .labelsHidden()
            .frame(width: 24, height: 24)
            .onChange(of: color) { _, newValue in
                onCommit(newValue.toCSSRGBAString())
            }
            .help(label)
    }
}

extension Color {
    public func toCSSRGBAString() -> String {
        #if os(macOS)
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .clear
        let red = Int((nsColor.redComponent * 255).rounded())
        let green = Int((nsColor.greenComponent * 255).rounded())
        let blue = Int((nsColor.blueComponent * 255).rounded())
        let alpha = nsColor.alphaComponent
        if alpha >= 0.999 {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }
        return String(format: "rgba(%d, %d, %d, %.3g)", red, green, blue, alpha)
        #else
        return "#000000"
        #endif
    }
}
