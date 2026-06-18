import LumiUI
import SwiftUI

struct ConversationTitleHeaderView: View {
    @LumiTheme private var theme

    let title: String
    let isSending: Bool

    var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.appMicro)
                    .foregroundColor(theme.primary)
                    .overlay {
                        if isSending {
                            PulseRipple(color: theme.primary)
                        }
                    }

                Text(title)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
            }
        }
    }
