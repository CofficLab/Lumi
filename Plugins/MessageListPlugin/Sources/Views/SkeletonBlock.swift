import SwiftUI

/// A rounded skeleton block with a soft horizontal shimmer sweep.
///
/// Used as a building block for skeleton screens (e.g. `MessageSkeletonView`).
/// The block animates a gradient sweeping from leading to trailing edge at a
/// fixed period; the color is derived from the passed-in base color so it
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

#Preview("Skeleton block") {
    VStack(alignment: .leading, spacing: 12) {
        SkeletonBlock(color: .gray.opacity(0.15))
            .frame(height: 14)
        SkeletonBlock(color: .gray.opacity(0.15))
            .frame(width: 220, height: 14)
        SkeletonBlock(color: .gray.opacity(0.15), cornerRadius: 12)
            .frame(width: 120, height: 32)
    }
    .padding(24)
    .frame(width: 320, height: 220)
}
