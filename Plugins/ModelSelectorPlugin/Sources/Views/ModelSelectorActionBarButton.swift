import LumiCoreLLMProvider
import LumiCoreMessage
import LumiKernel
import LumiUI
import SwiftUI

/// Action Bar 上的模型选择按钮
struct ModelSelectorActionBarButton: View {
    @LumiTheme private var theme
    let llmProvider: any LLMProviderManaging

    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .medium))
                Text(providerLabel)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: isPopoverPresented ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.textTertiary.opacity(0.2))
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            ProviderListPopover(llmProvider: llmProvider, isPresented: $isPopoverPresented)
                .frame(width: 300, height: 250)
        }
        .accessibilityLabel("Select Model")
    }

    private var providerLabel: String {
        let providers = llmProvider.allLLMProviders()
        guard let selectedID = llmProvider.selectedProviderID,
              let provider = providers.first(where: { type(of: $0).info.id == selectedID })
        else {
            // Fall back to first provider
            guard let first = providers.first else {
                return "No Provider"
            }
            let info = type(of: first).info
            if let model = info.availableModels.first {
                let displayModel = info.modelDisplayNames[model] ?? model
                return "\(info.displayName) · \(displayModel)"
            }
            return info.displayName
        }

        let info = type(of: provider).info
        if let model = info.availableModels.first {
            let displayModel = info.modelDisplayNames[model] ?? model
            return "\(info.displayName) · \(displayModel)"
        }
        return info.displayName
    }
}

// MARK: - Provider List Popover

private struct ProviderListPopover: View {
    @LumiTheme private var theme
    let llmProvider: any LLMProviderManaging
    @Binding var isPresented: Bool

    private var providerInfos: [LumiLLMProviderInfo] {
        llmProvider.allLLMProviders().map { type(of: $0).info }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Provider")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.surface)

            Divider()

            // Provider List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(providerInfos, id: \.id) { info in
                        ProviderRow(
                            providerInfo: info,
                            isSelected: info.id == llmProvider.selectedProviderID,
                            onSelect: {
                                llmProvider.selectProvider(id: info.id)
                                isPresented = false
                            }
                        )
                    }
                }
                .padding(8)
            }
        }
        .background(theme.background)
    }
}

// MARK: - Provider Row

private struct ProviderRow: View {
    @LumiTheme private var theme
    let providerInfo: LumiLLMProviderInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(providerInfo.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textPrimary)

                    Text("\(providerInfo.availableModels.count) models")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? theme.primary.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
