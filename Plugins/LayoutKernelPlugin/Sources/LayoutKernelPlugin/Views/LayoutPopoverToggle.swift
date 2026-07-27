import SwiftUI
import LumiUI

struct LayoutPopoverToggle: View {
    @LumiTheme private var theme
    @Binding var isOn: Bool
    let icon: String
    let title: String

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textPrimary)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            }
        }
        .toggleStyle(.checkbox)
    }
}
