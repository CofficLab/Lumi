
import LumiCoreKit
import LumiUI
import SwiftUI

struct ModelAvailabilityView: View {
    @LumiTheme private var theme

    let chatService: any LumiChatServicing

    @ObservedObject private var store = LLMAvailabilityStore.shared

    var body: some View {
        List {
            // MARK: - 检测状态

            if store.isCheckingAll {
                Section {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(LumiPluginLocalization.string("Checking availability...", bundle: .module))
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }

            // MARK: - 可用的供应商+模型

            let availableProviders = store.providers.filter { $0.hasAvailableModels }
            if !availableProviders.isEmpty {
                Section(LumiPluginLocalization.string("Available", bundle: .module)) {
                    ForEach(availableProviders) { provider in
                        providerRow(provider)
                    }
                }
            }

            // MARK: - 不可用的供应商

            let unavailableProviders = store.providers.filter { !$0.hasAvailableModels }
            if !unavailableProviders.isEmpty {
                Section(LumiPluginLocalization.string("Unavailable", bundle: .module)) {
                    ForEach(unavailableProviders) { provider in
                        providerRow(provider)
                    }
                }
            }

            // MARK: - 空状态

            if store.providers.isEmpty {
                Section {
                    AppEmptyState(
                        icon: "network.slash",
                        title: LumiPluginLocalization.string("No Providers Registered", bundle: .module)
                    )
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.background)
    }

    // MARK: - Provider Row

    @ViewBuilder
    private func providerRow(_ provider: LLMProviderAvailability) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(provider.displayName)
                    .font(.system(size: 15, weight: .semibold))

                if provider.hasAvailableModels {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                }
            }

            ForEach(provider.models) { model in
                modelRow(model)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Model Row

    @ViewBuilder
    private func modelRow(_ model: LLMModelAvailability) -> some View {
        HStack(spacing: 6) {
            statusIcon(model.status)

            Text(model.modelId)
                .font(.system(size: 13))
                .foregroundColor(theme.textPrimary)

            Spacer()

            statusText(model.status)
        }
        .padding(.leading, 8)
    }

    // MARK: - Status Components

    @ViewBuilder
    private func statusIcon(_ status: LLMAvailabilityStatus) -> some View {
        switch status {
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 11))
        case .checking:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        case .unavailable(let failure):
            if failure.reason == .unsupportedModel {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(theme.textSecondary)
                    .font(.system(size: 11))
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 11))
            }
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
        }
    }

    @ViewBuilder
    private func statusText(_ status: LLMAvailabilityStatus) -> some View {
        switch status {
        case .available:
            Text(LumiPluginLocalization.string("Available", bundle: .module))
                .font(.appCaption)
                .foregroundColor(.green)
        case .checking:
            Text(LumiPluginLocalization.string("Checking...", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        case .unavailable(let failure):
            AvailabilityFailureStatusLabel(failure: failure)
        case .unknown:
            Text(LumiPluginLocalization.string("Unknown", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
    }
}
