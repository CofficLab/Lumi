import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

/// 应用启动时的 Loading 页面。
struct LoadingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @LumiMotionPreferenceReader private var motionPreference
    @State private var isBreathing = false

    private var isDark: Bool { colorScheme == .dark }

    // Keep the bootstrap screen independent from the app theme. The active theme
    // is not available until the kernel finishes loading its plugins.
    private var backgroundColor: Color {
        Color(hex: isDark ? "11131A" : "F7F8FC")
    }

    private var primaryColor: Color {
        Color(hex: isDark ? "A79BFF" : "6558D8")
    }

    private var secondaryTextColor: Color {
        Color(hex: isDark ? "D7D8E8" : "5D6074")
    }

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: DesignTokens.Spacing.xxl) {
                Spacer()

                breathingMark

                VStack(spacing: DesignTokens.Spacing.md) {
                    Text("Lumi")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(isDark ? Color.white : Color(hex: "29283D"))

                    Text(LumiLocalization.string("Loading components and plugins…", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(secondaryTextColor)
                }
                .frame(maxWidth: 320)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .onAppear {
            guard motionPreference.allowsMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }

    private var breathingMark: some View {
        ZStack {
            Circle()
                .fill(primaryColor.opacity(isBreathing ? 0.10 : 0.16))
                .frame(width: 128, height: 128)
                .blur(radius: isBreathing ? 22 : 15)
                .scaleEffect(isBreathing ? 1.12 : 0.92)

            Circle()
                .stroke(primaryColor.opacity(isBreathing ? 0.22 : 0.38), lineWidth: 1)
                .frame(width: 92, height: 92)
                .scaleEffect(isBreathing ? 1.08 : 0.94)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [primaryColor, primaryColor.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 54, height: 54)
                .shadow(color: primaryColor.opacity(isBreathing ? 0.42 : 0.28), radius: isBreathing ? 18 : 11)
                .scaleEffect(isBreathing ? 1.05 : 0.96)

            Circle()
                .fill(Color.white.opacity(isDark ? 0.36 : 0.62))
                .frame(width: 12, height: 12)
                .offset(x: -10, y: -11)
                .blur(radius: 0.5)
        }
        .frame(width: 140, height: 140)
        .accessibilityHidden(true)
    }

    // MARK: - Background

    private var backgroundView: some View {
        GeometryReader { geometry in
            let maxRadius = max(geometry.size.width, geometry.size.height)

            RadialGradient(
                gradient: Gradient(colors: [
                    primaryColor.opacity(isDark ? 0.18 : 0.10),
                    primaryColor.opacity(isDark ? 0.07 : 0.04),
                    backgroundColor.opacity(0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: maxRadius * 0.8
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("LoadingView") {
        LoadingView()
    }

    #Preview("LoadingView - Light") {
        LoadingView()
        .preferredColorScheme(.light)
    }

    #Preview("LoadingView - Dark") {
        LoadingView()
        .preferredColorScheme(.dark)
    }
#endif
