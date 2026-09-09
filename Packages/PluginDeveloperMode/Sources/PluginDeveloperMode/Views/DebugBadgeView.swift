#if DEBUG
import SwiftUI
import KitLocalization
import LumiUI

/// Indicates that the app is running a Debug build.
struct DebugBadgeView: View {
    @LumiTheme private var theme

    var body: some View {
        Text(LumiPluginLocalization.string("DEBUG"))
            .font(.appMicroEmphasized)
            .tracking(0.3)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.warning, in: Capsule())
    }
}
#endif
