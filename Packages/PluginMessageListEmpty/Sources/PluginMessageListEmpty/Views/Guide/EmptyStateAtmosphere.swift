import LumiUI
import SwiftUI

/// A quiet, theme-driven backdrop for empty states.
///
/// The decoration is intentionally built from semantic theme colors so it
/// remains coherent across light, dark, and custom theme packs.
struct EmptyStateAtmosphere: View {
    @LumiTheme private var theme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                theme.background

                RadialGradient(
                    colors: [
                        theme.primary.opacity(0.075),
                        theme.primarySecondary.opacity(0.025),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: 12,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.68
                )

                Circle()
                    .fill(theme.primary.opacity(0.055))
                    .frame(width: 420, height: 420)
                    .blur(radius: 48)
                    .offset(x: -proxy.size.width * 0.25, y: -proxy.size.height * 0.22)

                Circle()
                    .fill(theme.info.opacity(0.035))
                    .frame(width: 340, height: 340)
                    .blur(radius: 42)
                    .offset(x: proxy.size.width * 0.31, y: proxy.size.height * 0.22)

                EmptyStateCapabilityBackdrop()

                // Keep a calm, low-contrast reading zone over the center so
                // decorative motifs never compete with the empty-state copy.
                RadialGradient(
                    colors: [
                        theme.background.opacity(0.58),
                        theme.background.opacity(0.26),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 120,
                    endRadius: min(proxy.size.width, proxy.size.height) * 0.38
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Static, low-contrast line art that hints at Lumi's capability groups.
///
/// The four motifs sit at the perimeter as visual context, never as controls,
/// so they never compete with the empty-state title or prompt suggestions.
private struct EmptyStateCapabilityBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let shortestEdge = min(proxy.size.width, proxy.size.height)
            // Scale down on compact windows instead of dropping the lower
            // motifs, so resizing never makes two corners blink out.
            let motifScale: CGFloat = shortestEdge < 620 ? 0.76 : 1
            let insetX = max(82, proxy.size.width * 0.14)
            let insetY = max(84, proxy.size.height * 0.2)

            ZStack {
                CapabilityMotif(kind: .project)
                    .position(x: insetX, y: insetY)

                CapabilityMotif(kind: .creative)
                    .position(
                        x: min(proxy.size.width - insetX, proxy.size.width * 0.86),
                        y: insetY
                    )

                CapabilityMotif(kind: .system)
                    .position(
                        x: insetX,
                        y: min(proxy.size.height - insetY, proxy.size.height * 0.8)
                    )

                CapabilityMotif(kind: .web)
                    .position(
                        x: min(proxy.size.width - insetX, proxy.size.width * 0.86),
                        y: min(proxy.size.height - insetY, proxy.size.height * 0.8)
                    )
            }
            .scaleEffect(motifScale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Pure geometry for a capability motif.
///
/// Extracted from the SwiftUI views so the "every element sits inside the
/// card" rule is assertable in tests instead of being an implicit convention.
///
/// The card's vertical space splits into two bands that never overlap:
/// - `symbolBand` (y 21...63) holds the dominant symbol.
/// - `detailBand` (y 63...91) holds *either* the text rows used by `project`
///   and `creative`, *or* the pill used by `system` and `web` — never both,
///   because no single motif draws the two together.
enum CapabilityMotifGeometry {
    /// The fixed drawing canvas. The motif is centered on it.
    static let canvasSize = CGSize(width: 144, height: 112)

    /// The shared card, centered on the canvas.
    ///
    /// Bounds are x in [26, 118] and y in [21, 91], so the card has a visible
    /// margin on every side and can never be clipped.
    static let cardRect = CGRect(x: 26, y: 21, width: 92, height: 70)

    /// Upper band: the dominant symbol. Ends at y 62 so there is a real gap
    /// before the detail band rather than two abutting rectangles.
    static let symbolBand = CGRect(x: 26, y: 21, width: 92, height: 41)

    /// Lower band: text rows or a pill, never both.
    static let detailBand = CGRect(x: 26, y: 64, width: 92, height: 27)

    /// Center of the dominant symbol.
    static var symbolCenter: CGPoint {
        CGPoint(x: canvasSize.width / 2, y: symbolBand.midY)
    }

    /// The two text rows used by `project` and `creative`.
    ///
    /// Row one is full width and row two is shorter, so the block reads as
    /// text rather than as a single stray rule.
    static let textRows = [
        CGRect(x: 46, y: 68, width: 52, height: 1),
        CGRect(x: 46, y: 78, width: 38, height: 1),
    ]

    /// The address-bar / status-bar pill used by `system` and `web`.
    static let pillRect = CGRect(x: 44, y: 71, width: 56, height: 9)

    /// The small dot at the pill's leading edge.
    static let dotRect = CGRect(x: 47, y: 73.5, width: 4, height: 4)

    /// True when `rect` sits fully inside the card. Tests use this to catch a
    /// future motif that pushes geometry past the card edge again.
    static func contains(_ rect: CGRect) -> Bool {
        cardRect.contains(rect)
    }
}

/// One perimeter motif per capability group.
///
/// Every motif follows the same construction, so the four read as a set:
/// - The shared card from `CapabilityMotifGeometry`, centered on the canvas.
/// - One dominant SF Symbol that carries the meaning on its own.
/// - At most two supporting strokes in the detail band, all inside the card.
///
/// `.clipped()` is a safety net: a future motif that rotates or offsets
/// geometry past the canvas edge still cannot bleed onto the central copy.
private struct CapabilityMotif: View {
    @LumiTheme private var theme
    let kind: Kind

    enum Kind {
        case project
        case creative
        case system
        case web
    }

    private var line: Color { theme.textSecondary.opacity(0.16) }
    private var softLine: Color { theme.primary.opacity(0.13) }
    private var accent: Color { theme.primary.opacity(0.24) }
    private var secondaryAccent: Color { theme.primarySecondary.opacity(0.2) }

    var body: some View {
        ZStack {
            card
            switch kind {
            case .project:
                projectMotif
            case .creative:
                creativeMotif
            case .system:
                systemMotif
            case .web:
                webMotif
            }
        }
        .frame(
            width: CapabilityMotifGeometry.canvasSize.width,
            height: CapabilityMotifGeometry.canvasSize.height
        )
        .clipped()
        .drawingGroup()
    }

    /// The shared card every motif sits on.
    private var card: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(line, lineWidth: 1.5)
            .frame(
                width: CapabilityMotifGeometry.cardRect.width,
                height: CapabilityMotifGeometry.cardRect.height
            )
    }

    /// `.project` — a folder over two text rows.
    private var projectMotif: some View {
        ZStack {
            symbol("folder", size: 34)
            textRows(stroke: softLine)
        }
    }

    /// `.creative` — a paintbrush over a single brush stroke.
    private var creativeMotif: some View {
        ZStack {
            symbol("paintbrush", size: 34)

            Path { path in
                path.move(to: CGPoint(x: 44, y: 74))
                path.addCurve(
                    to: CGPoint(x: 100, y: 74),
                    control1: CGPoint(x: 60, y: 67),
                    control2: CGPoint(x: 84, y: 81)
                )
            }
            .stroke(secondaryAccent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    /// `.system` — a terminal over a status pill.
    private var systemMotif: some View {
        ZStack {
            symbol("terminal", size: 34)
            pill(stroke: softLine)
            leadingDot
        }
    }

    /// `.web` — a globe over an address-bar pill.
    private var webMotif: some View {
        ZStack {
            symbol("globe", size: 36)
            pill(stroke: accent)
            leadingDot
        }
    }

    private func symbol(_ name: String, size: CGFloat) -> some View {
        let center = CapabilityMotifGeometry.symbolCenter
        let half = CapabilityMotifGeometry.canvasSize.height / 2
        return Image(systemName: name)
            .font(.system(size: size, weight: .light))
            .foregroundStyle(accent)
            .offset(x: center.x - CapabilityMotifGeometry.canvasSize.width / 2, y: center.y - half)
    }

    private func textRows(stroke: Color) -> some View {
        Path { path in
            for row in CapabilityMotifGeometry.textRows {
                path.move(to: CGPoint(x: row.minX, y: row.minY))
                path.addLine(to: CGPoint(x: row.maxX, y: row.minY))
            }
        }
        .stroke(stroke, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    private func pill(stroke: Color) -> some View {
        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
            .stroke(stroke, lineWidth: 1.5)
            .frame(
                width: CapabilityMotifGeometry.pillRect.width,
                height: CapabilityMotifGeometry.pillRect.height
            )
            .offset(y: CapabilityMotifGeometry.pillRect.midY - CapabilityMotifGeometry.canvasSize.height / 2)
    }

    private var leadingDot: some View {
        let dot = CapabilityMotifGeometry.dotRect
        return Circle()
            .fill(secondaryAccent)
            .frame(width: dot.width, height: dot.height)
            .offset(
                x: dot.midX - CapabilityMotifGeometry.canvasSize.width / 2,
                y: dot.midY - CapabilityMotifGeometry.canvasSize.height / 2
            )
    }
}

struct EmptyStateHeroIcon: View {
    @LumiTheme private var theme
    let systemImage: String

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.primary.opacity(0.085))
                .frame(width: 84, height: 84)

            Circle()
                .stroke(theme.primary.opacity(0.14), lineWidth: 1)
                .frame(width: 76, height: 76)

            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(theme.primaryGradient)
                .shadow(color: theme.primary.opacity(0.14), radius: 10, y: 4)
        }
        .accessibilityHidden(true)
    }
}
