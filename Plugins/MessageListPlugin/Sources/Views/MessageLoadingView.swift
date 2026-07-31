import LumiUI
import SwiftUI

/// A rounded skeleton block with a soft horizontal shimmer sweep.
///
/// Used as a building block for skeleton screens (e.g. the conversation skeleton
/// below). The block animates a gradient sweeping from leading to trailing edge
/// at a fixed period; the color is derived from the passed-in base color so it
/// adapts to light and dark themes automatically.
struct SkeletonBlock: View {
    /// Base fill color for the skeleton block. Caller should pass a low-contrast
    /// theme color (e.g. `theme.textSecondary.opacity(0.08)`).
    let color: Color

    /// Corner radius. Defaults to 6, matching typical message bubble radii.
    var cornerRadius: CGFloat = 6

    /// Width of the shimmer highlight band, as a fraction of the block width.
    /// 0.4 gives a soft sweep without overwhelming the block.
    private let bandFraction: CGFloat = 0.4

    /// Period of one full shimmer sweep, in seconds. 1.4s reads as calm
    /// "breathing" rather than anxious spinning.
    private let period: Double = 1.4

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            // Animate from -bandFraction to 1 so the highlight enters from the
            // left edge and exits past the right edge of the block.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = phase(for: context.date)
                let bandWidth = width * bandFraction
                let leading = -bandWidth + (width + bandWidth) * t

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color)
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.35), location: 0.5),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: bandWidth)
                        .offset(x: leading)
                        .blendMode(.plusLighter)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    )
            }
        }
    }

    /// Maps a date to a 0...1 phase used to drive the shimmer offset.
    /// - Parameter date: The current timeline tick date.
    /// - Returns: Normalized phase in `[0, 1)`.
    private func phase(for date: Date) -> CGFloat {
        let seconds = date.timeIntervalSinceReferenceDate
        let raw = (seconds.truncatingRemainder(dividingBy: period)) / period
        return CGFloat(raw)
    }
}

/// Loading skeleton for the message list.
///
/// Mimics the visual rhythm of a real conversation: a user bubble (right) and
/// an assistant bubble with avatar (left) interleaved several times. Each
/// block pulses with a soft shimmer sweep; line widths vary per row so the
/// skeleton reads as "alive" rather than as a perfectly mechanical grid.
///
/// Pure layout — no real data is touched.
struct MessageSkeletonView: View {
    @LumiTheme private var theme

    /// How many pseudo-turns to draw. 5 is enough to fill a typical window
    /// without scrolling, while keeping the animation cheap.
    private let turnCount = 5

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<turnCount, id: \.self) { index in
                turnRow(at: index)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Turn rows

    /// Renders one conversation turn: user bubble (right) followed by
    /// assistant bubble with avatar (left). The exact shape varies per index
    /// to avoid a perfectly mechanical look.
    /// - Parameter index: Zero-based row index.
    /// - Returns: A view containing the pseudo turn.
    @ViewBuilder
    private func turnRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            userBubble()
            assistantBubble(index: index)
        }
    }

    /// A right-aligned user bubble: avatar dot + one short block + one longer
    /// block on a card-like background.
    /// - Returns: A right-aligned pseudo user bubble.
    private func userBubble() -> some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer(minLength: 32)
            VStack(alignment: .trailing, spacing: 6) {
                SkeletonBlock(color: baseFill, cornerRadius: 8)
                    .frame(width: 180, height: 12)
                SkeletonBlock(color: baseFill, cornerRadius: 8)
                    .frame(width: 240, height: 12)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            SkeletonBlock(color: baseFill, cornerRadius: 14)
                .frame(width: 28, height: 28)
        }
    }

    /// A left-aligned assistant bubble: avatar + multi-line content.
    /// - Parameter index: Row index, used to vary line widths so the skeleton
    ///   doesn't feel mechanical.
    /// - Returns: A left-aligned pseudo assistant bubble.
    private func assistantBubble(index: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            SkeletonBlock(color: baseFill, cornerRadius: 14)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(color: baseFill, cornerRadius: 8)
                    // Vary widths by index so different turns look distinct.
                    .frame(width: lineWidth(for: index, line: 0, max: 280), height: 12)
                SkeletonBlock(color: baseFill, cornerRadius: 8)
                    .frame(width: lineWidth(for: index, line: 1, max: 280), height: 12)
                if index % 2 == 0 {
                    SkeletonBlock(color: baseFill, cornerRadius: 8)
                        .frame(width: lineWidth(for: index, line: 2, max: 200), height: 12)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            Spacer(minLength: 32)
        }
    }

    // MARK: - Theme tokens

    /// Low-contrast skeleton fill that adapts to light/dark themes.
    private var baseFill: Color {
        theme.textSecondary.opacity(0.12)
    }

    /// Subtle bubble background, one notch above the skeleton fill.
    private var bubbleBackground: Color {
        theme.textSecondary.opacity(0.05)
    }

    /// Returns a varied line width per row/line so the skeleton looks organic.
    /// - Parameters:
    ///   - index: Row index.
    ///   - line: Line index inside the bubble (0-based).
    ///   - max: Maximum desired width for the longest line.
    /// - Returns: A pseudo-random but stable width value.
    private func lineWidth(for index: Int, line: Int, max: CGFloat) -> CGFloat {
        // Simple deterministic pattern — varies with both inputs to avoid a
        // grid-aligned feel. Stays in 60%...100% of `max` so all lines are
        // clearly readable.
        let seed = (index * 7 + line * 3 + 5) % 5
        let fraction: CGFloat = [0.62, 0.78, 0.88, 0.72, 0.95][seed]
        return max * fraction
    }
}

/// Loading state view shown while the message list is fetching data.
///
/// Renders a shimmering conversation skeleton so the user sees a preview of
/// what the loaded list will look like, instead of an empty screen. A small
/// "Loading messages…" caption sits at the bottom to keep the loading state
/// explicit.
struct MessageLoadingView: View {
    @LumiTheme private var theme

    static let useSimple: Bool = true

    var body: some View {
        if Self.useSimple {
            ProgressView()
        } else {
            VStack(spacing: 0) {
                // Conversation-shaped skeleton: user/assistant bubbles interleaved
                // a few times. Takes all available space so the caption can sit at
                // the bottom of the panel rather than the center.
                MessageSkeletonView()

                // Trailing caption — explicit loading affordance for users who
                // don't notice the skeleton animation.
                Text(String(localized: "Loading messages…", bundle: .module))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary.opacity(0.7))
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("Message loading") {
    MessageLoadingView()
        .frame(width: 480, height: 600)
}
