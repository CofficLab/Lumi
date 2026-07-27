import SwiftUI

/// Layout constants for the message list.
///
/// Kept separate so the chat list windowing behavior and row spacing stay easy
/// to regression-test, matching the old 4.19.0 structure.
public enum ChatMessageListLayout {
    /// Markdown renderers inside the list should delegate vertical scrolling to the outer list.
    public static let prefersOuterScrollForMarkdown = true

    public static let messageRowInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    public static let messageRowHorizontalPadding: CGFloat = 6
    public static let messageRowVerticalPadding: CGFloat = 4
}
