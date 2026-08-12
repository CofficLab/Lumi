import SwiftUI

/// BookletMaker 在内核与插件初始化期间显示的品牌启动页。
struct BookletMakerLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    private var isDark: Bool { colorScheme == .dark }

    private var backgroundColor: Color {
        Color(red: isDark ? 0.055 : 0.955, green: isDark ? 0.075 : 0.965, blue: isDark ? 0.13 : 0.985)
    }

    private var brandColor: Color {
        Color(red: isDark ? 0.35 : 0.15, green: isDark ? 0.50 : 0.27, blue: isDark ? 0.94 : 0.57)
    }

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 24) {
                bookletMark

                VStack(spacing: 9) {
                    Text("BookletMaker")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(isDark ? Color.white : Color(red: 0.10, green: 0.13, blue: 0.22))

                    ProgressView()
                        .controlSize(.small)
                        .tint(brandColor)
                        .accessibilityLabel("Loading BookletMaker")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }

    private var backgroundView: some View {
        GeometryReader { geometry in
            let radius = max(geometry.size.width, geometry.size.height)

            RadialGradient(
                colors: [
                    brandColor.opacity(isDark ? 0.22 : 0.14),
                    brandColor.opacity(isDark ? 0.07 : 0.04),
                    backgroundColor.opacity(0),
                ],
                center: .center,
                startRadius: 0,
                endRadius: radius * 0.72
            )
            .ignoresSafeArea()
        }
    }

    private var bookletMark: some View {
        ZStack {
            Circle()
                .fill(brandColor.opacity(isBreathing ? 0.13 : 0.20))
                .frame(width: 150, height: 150)
                .blur(radius: isBreathing ? 22 : 14)
                .scaleEffect(isBreathing ? 1.08 : 0.94)

            HStack(spacing: 4) {
                page(lines: [44, 36, 27], alignment: .trailing)
                    .rotationEffect(.degrees(isBreathing ? -2.5 : -0.8), anchor: .bottomTrailing)

                page(lines: [44, 36, 27], alignment: .leading)
                    .rotationEffect(.degrees(isBreathing ? 2.5 : 0.8), anchor: .bottomLeading)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(brandColor)
                    .shadow(color: brandColor.opacity(isDark ? 0.42 : 0.28), radius: 20, y: 10)
            )
            .scaleEffect(isBreathing ? 1.02 : 0.98)
        }
        .frame(width: 170, height: 170)
        .accessibilityHidden(true)
    }

    private func page(lines: [CGFloat], alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 9) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, width in
                Capsule()
                    .fill(Color(red: 0.58, green: 0.65, blue: 0.75).opacity(0.82))
                    .frame(width: width, height: 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 25)
        .frame(width: 68, height: 104)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.98, green: 0.985, blue: 0.995))
        )
    }
}
