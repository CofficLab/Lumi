import LumiUI
import SwiftUI

struct ProviderBadge: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        Text(MiniMaxTokenPlanProvider.shortName)
            .font(.appMicro)
            .fontWeight(.semibold)
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(theme.textSecondary.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(theme.textTertiary.opacity(0.25), lineWidth: 0.5)
            )
    }
}