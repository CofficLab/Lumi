import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatProviderPicker: View {
    @LumiTheme private var theme

    let chatService: any LumiChatServicing
    let onChange: () -> Void
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 15))
                Text(providerLabel)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ChatModelSelectorView(
                chatService: chatService,
                onChange: onChange,
                onClose: {
                    isPresented = false
                }
            )
        }
        .accessibilityLabel("Select Model")
    }

    private var providerLabel: String {
        guard let providerID = chatService.selectedProviderID,
              let provider = chatService.providerInfos.first(where: { $0.id == providerID })
        else {
            return "Local Placeholder"
        }

        if let model = chatService.selectedModel {
            return "\(provider.displayName) · \(model)"
        }
        return provider.displayName
    }
}
