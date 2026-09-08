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
/// The motifs intentionally stay at the perimeter. They are visual context,
/// not controls, so they never compete with the empty-state title or prompts.
private struct EmptyStateCapabilityBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let isCompact = min(proxy.size.width, proxy.size.height) < 620
            let motifScale: CGFloat = isCompact ? 0.76 : 1

            ZStack {
                CapabilityMotif(kind: .project)
                    .frame(width: 144, height: 112)
                    .scaleEffect(motifScale)
                    .position(
                        x: max(82, proxy.size.width * 0.14),
                        y: max(84, proxy.size.height * 0.2)
                    )

                CapabilityMotif(kind: .creative)
                    .frame(width: 144, height: 112)
                    .scaleEffect(motifScale)
                    .position(
                        x: min(proxy.size.width - 82, proxy.size.width * 0.86),
                        y: max(84, proxy.size.height * 0.2)
                    )

                if !isCompact {
                    CapabilityMotif(kind: .system)
                        .frame(width: 144, height: 112)
                        .position(
                            x: max(82, proxy.size.width * 0.14),
                            y: min(proxy.size.height - 86, proxy.size.height * 0.8)
                        )

                    CapabilityMotif(kind: .web)
                        .frame(width: 144, height: 112)
                        .position(
                            x: min(proxy.size.width - 82, proxy.size.width * 0.86),
                            y: min(proxy.size.height - 86, proxy.size.height * 0.8)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

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
        .frame(width: 144, height: 112)
        .drawingGroup()
    }

    private var projectMotif: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(line, lineWidth: 1.5)
                .frame(width: 76, height: 58)
                .offset(x: 12, y: 3)

            Path { path in
                path.move(to: CGPoint(x: 42, y: 41))
                path.addLine(to: CGPoint(x: 42, y: 77))
                path.addLine(to: CGPoint(x: 28, y: 77))
                path.move(to: CGPoint(x: 42, y: 52))
                path.addLine(to: CGPoint(x: 60, y: 52))
                path.move(to: CGPoint(x: 42, y: 65))
                path.addLine(to: CGPoint(x: 61, y: 65))
            }
            .stroke(softLine, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            Image(systemName: "curlybraces")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(accent)
                .offset(x: -42, y: -2)

            Circle()
                .fill(secondaryAccent)
                .frame(width: 5, height: 5)
                .offset(x: 31, y: 41)
        }
    }

    private var creativeMotif: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(line, lineWidth: 1.5)
                .frame(width: 78, height: 60)
                .rotationEffect(.degrees(-6))
                .offset(x: -2, y: 2)

            Circle()
                .stroke(accent, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .offset(x: -18, y: -8)

            Path { path in
                path.move(to: CGPoint(x: 66, y: 35))
                path.addCurve(
                    to: CGPoint(x: 91, y: 63),
                    control1: CGPoint(x: 75, y: 45),
                    control2: CGPoint(x: 80, y: 60)
                )
                path.addLine(to: CGPoint(x: 102, y: 72))
            }
            .stroke(secondaryAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: CGPoint(x: 92, y: 67))
                path.addLine(to: CGPoint(x: 102, y: 72))
                path.addLine(to: CGPoint(x: 98, y: 61))
            }
            .stroke(secondaryAccent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            Circle()
                .fill(softLine)
                .frame(width: 5, height: 5)
                .offset(x: -43, y: 31)
        }
    }

    private var systemMotif: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(line, lineWidth: 1.5)
                .frame(width: 78, height: 55)
                .offset(x: -8, y: -3)

            Path { path in
                path.move(to: CGPoint(x: 24, y: 38))
                path.addLine(to: CGPoint(x: 35, y: 38))
                path.addLine(to: CGPoint(x: 40, y: 43))
                path.move(to: CGPoint(x: 50, y: 38))
                path.addLine(to: CGPoint(x: 66, y: 38))
                path.move(to: CGPoint(x: 24, y: 51))
                path.addLine(to: CGPoint(x: 66, y: 51))
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            Circle()
                .fill(secondaryAccent)
                .frame(width: 8, height: 8)
                .offset(x: 23, y: 35)

            Circle()
                .fill(softLine)
                .frame(width: 6, height: 6)
                .offset(x: 64, y: 48)

            Image(systemName: "gearshape")
                .font(.system(size: 21, weight: .light))
                .foregroundStyle(softLine)
                .offset(x: 47, y: 24)
        }
    }

    private var webMotif: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(line, lineWidth: 1.5)
                .frame(width: 82, height: 59)
                .offset(x: 4, y: 0)

            Path { path in
                path.move(to: CGPoint(x: 25, y: 35))
                path.addLine(to: CGPoint(x: 85, y: 35))
            }
            .stroke(softLine, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            Circle()
                .stroke(accent, lineWidth: 1.5)
                .frame(width: 31, height: 31)
                .offset(x: 2, y: 15)

            Path { path in
                path.move(to: CGPoint(x: -14, y: 50))
                path.addCurve(
                    to: CGPoint(x: 18, y: 50),
                    control1: CGPoint(x: -6, y: 37),
                    control2: CGPoint(x: 10, y: 37)
                )
                path.move(to: CGPoint(x: 2, y: 35))
                path.addLine(to: CGPoint(x: 2, y: 65))
            }
            .stroke(softLine, style: StrokeStyle(lineWidth: 1.25, lineCap: .round))

            Circle()
                .fill(secondaryAccent)
                .frame(width: 6, height: 6)
                .offset(x: -35, y: 15)
        }
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
