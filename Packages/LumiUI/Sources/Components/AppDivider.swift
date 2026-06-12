import SwiftUI

/// Layout shell divider (horizontal or vertical). Uses `theme.divider`.
public struct AppDivider: View {
    @LumiTheme private var theme
    let axis: Axis

    public init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    public var body: some View {
        switch axis {
        case .horizontal:
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)
        case .vertical:
            Rectangle()
                .fill(theme.divider)
                .frame(width: 1)
        }
    }
}
