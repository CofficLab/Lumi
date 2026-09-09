import CoreGraphics

/// Geometry used by Brief's post-send conversation positioning.
enum MessageListSendPositioning {
    /// The top of the newly sent turn should land around the upper quarter of
    /// the message-list viewport.
    static let targetTopFraction: CGFloat = 0.25

    /// Reserves the part of the viewport that is still empty below the active
    /// turn. As the activity view grows, the reserve shrinks by the same
    /// amount, keeping the sent message near the target position.
    static func tailReserve(
        viewportHeight: CGFloat,
        activeTurnHeight: CGFloat
    ) -> CGFloat {
        guard viewportHeight.isFinite,
              activeTurnHeight.isFinite,
              viewportHeight > 0,
              activeTurnHeight >= 0 else { return 0 }

        return max(
            0,
            viewportHeight * (1 - targetTopFraction) - activeTurnHeight
        )
    }
}
