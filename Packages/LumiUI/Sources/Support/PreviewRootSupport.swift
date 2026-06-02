import SwiftUI

/// Lightweight preview placeholder for package-local previews.
///
/// The app target has its own `ContentLayout` and root environment injection.
/// Plugin packages cannot depend on that app layer, so package previews use this
/// SDK-level placeholder when they need a root-sized surface.
public struct ContentLayout: View {
    public init() {}

    public var body: some View {
        Color.clear
            .frame(minWidth: 320, minHeight: 240)
    }
}

public extension View {
    /// Package-safe preview wrapper.
    ///
    /// The app target provides the real root environment. In packages this is an
    /// identity modifier so previews compile without depending on app internals.
    @_disfavoredOverload
    func inRootView() -> some View {
        self
    }

    /// Package-safe debug-bar placeholder for previews.
    @_disfavoredOverload
    func withDebugBar() -> some View {
        self
    }
}
