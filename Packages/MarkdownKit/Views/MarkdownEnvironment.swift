import SwiftUI

private struct PreferOuterScrollKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// When true, markdown and text renderers avoid nested scroll views and let the outer container own scrolling.
    var preferOuterScroll: Bool {
        get { self[PreferOuterScrollKey.self] }
        set { self[PreferOuterScrollKey.self] = newValue }
    }
}
