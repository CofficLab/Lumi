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

                Circle()
                    .stroke(theme.primary.opacity(0.09), lineWidth: 1)
                    .frame(width: 430, height: 430)
                    .offset(x: -proxy.size.width * 0.3, y: -proxy.size.height * 0.21)

                RoundedRectangle(cornerRadius: 180, style: .continuous)
                    .stroke(theme.primarySecondary.opacity(0.06), lineWidth: 1)
                    .frame(width: 620, height: 260)
                    .rotationEffect(.degrees(-18))
                    .offset(x: proxy.size.width * 0.31, y: proxy.size.height * 0.25)

                // Keep a calm, low-contrast reading zone over the center so
                // decorative strokes never compete with the empty-state copy.
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
