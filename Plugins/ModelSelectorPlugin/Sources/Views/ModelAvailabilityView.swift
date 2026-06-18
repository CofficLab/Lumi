import LumiCoreKit
import LumiUI
import SwiftUI

struct ModelAvailabilityView: View {
    @LumiTheme private var theme

    let chatService: any LumiChatServicing

    var body: some View {
        List {
            Section(LumiPluginLocalization.string("Registered Providers", bundle: .module)) {
                ForEach(chatService.providerInfos) { provider in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(provider.displayName)
                            .font(.system(size: 15, weight: .semibold))
                        Text(
                            String(
                                format: LumiPluginLocalization.string("%lld models", bundle: .module),
                                provider.availableModels.count
                            )
                        )
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                        Text(provider.description)
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(LumiPluginLocalization.string("Usage Signals", bundle: .module)) {
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
