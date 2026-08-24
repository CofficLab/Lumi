import LumiUI
import SwiftUI

/// Full-area loading veil with a soft breathing pulse instead of a static spinner.
struct ConnectBusyOverlay: View {
    @LumiTheme private var theme

    private let breathPeriod: TimeInterval = 1.8

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let phase = breathPhase(at: timeline.date)

            ZStack {
                veil(phase: phase)
                breathingIndicator(phase: phase)
            }
        }
        .transition(.opacity.animation(.easeOut(duration: 0.18)))
    }

    private func veil(phase: CGFloat) -> some View {
        Color.black.opacity(0.03 + Double(phase) * 0.04)
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
    }

    private func breathingIndicator(phase: CGFloat) -> some View {
        ZStack {
            BreathingRingLayer(phase: phase, accent: theme.primary)
            BreathingCore(phase: phase, accent: theme.primary)
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
        }
        .scaleEffect(0.98 + phase * 0.02)
    }

    private func breathPhase(at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: breathPeriod) / breathPeriod
        return CGFloat((sin(t * 2 * .pi) + 1) / 2)
    }
}

private struct BreathingRingLayer: View {
    let phase: CGFloat
    let accent: Color

    var body: some View {
        ZStack {
            BreathingRing(phase: phase, accent: accent, index: 0)
            BreathingRing(phase: phase, accent: accent, index: 1)
            BreathingRing(phase: phase, accent: accent, index: 2)
        }
    }
}

private struct BreathingRing: View {
    let phase: CGFloat
    let accent: Color
    let index: Int

    private var ringPhase: CGFloat {
        let offset = CGFloat(index) * 0.22
        return min(1, max(0, phase + offset - 0.22))
    }

    private var diameter: CGFloat {
        28 + CGFloat(index) * 16
    }

    var body: some View {
        Circle()
            .stroke(accent.opacity(0.12 + Double(ringPhase) * 0.18), lineWidth: 1.25)
            .frame(width: diameter, height: diameter)
            .scaleEffect(0.88 + ringPhase * 0.2)
            .opacity(0.2 + Double(1 - ringPhase) * 0.35)
    }
}

private struct BreathingCore: View {
    let phase: CGFloat
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.08 + Double(phase) * 0.06))
                .frame(width: 40, height: 40)
                .scaleEffect(0.94 + phase * 0.08)

            Image(systemName: "shippingbox")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent.opacity(0.55 + Double(phase) * 0.25))
                .scaleEffect(0.96 + phase * 0.06)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.12)
        ConnectBusyOverlay()
    }
    .frame(width: 520, height: 360)
}
