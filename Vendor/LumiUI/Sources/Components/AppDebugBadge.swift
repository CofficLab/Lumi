import SwiftUI

/// A lightweight overlay for identifying view boundaries during development.
public struct AppDebugBadgeModifier: ViewModifier {
    public let text: String
    public let color: Color
    public let alignment: Alignment

    public init(text: String, color: Color? = nil, alignment: Alignment = .topTrailing) {
        self.text = text
        self.color = color ?? Self.color(for: text)
        self.alignment = alignment
    }

    public func body(content: Content) -> some View {
        #if DEBUG
        content
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(color.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .allowsHitTesting(false)
            }
            .overlay(alignment: alignment) {
                Text(text)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(.white)
                    .background(color.opacity(0.85), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .allowsHitTesting(false)
                    .padding(8)
            }
        #else
        content
        #endif
    }

    private static func color(for text: String) -> Color {
        var hash: UInt64 = 5381
        for byte in text.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.62, brightness: 0.78)
    }
}

public extension View {
    /// Adds a deterministic, debug-only badge and dashed outline.
    func appDebugBadge(_ text: String, color: Color? = nil, alignment: Alignment = .topTrailing) -> some View {
        modifier(AppDebugBadgeModifier(text: text, color: color, alignment: alignment))
    }
}
