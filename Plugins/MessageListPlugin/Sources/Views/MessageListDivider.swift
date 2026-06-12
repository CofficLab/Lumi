import LumiUI
import SwiftUI

struct MessageListDivider: View {
    @LumiTheme private var theme

    var body: some View {
        Rectangle()
            .fill(theme.appSubtleBorder)
            .frame(height: 1)
    }
}
