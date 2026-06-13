import LumiCoreKit
import LumiUI
import SwiftUI

struct ModelAvailabilityView: View {
    @LumiTheme private var theme

    let chatService: any LumiChatServicing

    var body: some View {
        List {
            Section("Registered Providers") {
                ForEach(chatService.providerInfos) { provider in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(provider.displayName)
                            .font(.system(size: 15, weight: .semibold))
                        Text("\(provider.availableModels.count) models")
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                        Text(provider.description)
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Usage Signals") {
                Text(verbatim: LumiPluginLocalization.string(
                    "Availability is inferred from local chat history and provider registration. Use the Current tab to pick a model manually, or enable Auto routing.",
                    bundle: .module
                ))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.background)
    }
}
