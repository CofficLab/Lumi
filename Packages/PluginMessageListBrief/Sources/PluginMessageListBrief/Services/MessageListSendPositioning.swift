import CoreGraphics

/// Geometry used by Brief's post-send conversation positioning.
enum MessageListSendPositioning {
    /// The top of the newly sent turn should land around the upper quarter of
    /// the message-list viewport.
    static let targetTopFraction: CGFloat = 0.25

    /// Conservative reserve used while the live turn and conversation state
    /// are changing size.
    ///
    /// Measuring a streaming List row with a SwiftUI preference feeds every
    /// token-sized change back into List layout. Keep the reserve independent
    /// of row height so the layout has a stable value until the turn finishes.
    static func conservativeTailReserve(viewportHeight: CGFloat) -> CGFloat {
        guard viewportHeight.isFinite, viewportHeight > 0 else { return 0 }
        return viewportHeight * (1 - targetTopFraction)
    }
}
