import LumiUI
import SwiftUI

struct ModelSelectorDivider: View {
    enum Axis {
        case horizontal
        case vertical
    }

    @LumiTheme private var theme
    let axis: Axis

    var body: some View {
        Rectangle()
            .fill(theme.appSubtleBorder)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
    }
}
