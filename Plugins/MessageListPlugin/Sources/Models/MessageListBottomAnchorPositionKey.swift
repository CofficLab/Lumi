import SwiftUI

/// PreferenceKey used to track the bottom anchor's max-Y position for detecting
/// whether the user is scrolled to the bottom of the message list.
struct MessageListBottomAnchorPositionKey: PreferenceKey {
    static let defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
