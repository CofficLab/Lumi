import LumiUI
import SwiftUI

struct AppDivider: View {
    @LumiTheme private var theme
    let axis: Axis

    init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    var body: some View {
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
