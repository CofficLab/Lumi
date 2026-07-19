import LumiKernel
import LumiUI
import SwiftUI

struct ChatPendingMessagesView: View {
    @LumiTheme private var theme

    let messages: [LumiPendingMessage]
    let onRemove: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondary)
                Text(verbatim: LumiPluginLocalization.string("Waiting to Send", bundle: .module))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                Text("(\(messages.count))")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondary)
                Spacer()
            }

            ForEach(messages) { message in
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9))
                        .foregroundColor(theme.textSecondary.opacity(0.6))

                    Text(message.content.prefix(80))
                        .font(.system(size: 11))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        onRemove(message.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .padding(10)
        .background(theme.surface.opacity(0.5))
    }
}
