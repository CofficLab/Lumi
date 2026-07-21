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
                Text(buttonLabel)
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
            ProviderModelPopover(llmProvider: llmProvider, isPresented: $isPopoverPresented)
                .frame(width: 320, height: 350)
        }
        .accessibilityLabel("Select Model")
    }

    private var buttonLabel: String {
        guard let providerID = llmProvider.selectedProviderID,
              let provider = llmProvider.allLLMProviders().first(where: { type(of: $0).info.id == providerID })
        else {
            return "Select Provider"
        }
        let info = type(of: provider).info
        if let model = llmProvider.selectedModel {
            let displayModel = info.modelDisplayNames[model] ?? model
            return "\(info.displayName) · \(displayModel)"
        }
        return info.displayName
    }
}

// MARK: - Provider Model Popover

private struct ProviderModelPopover: View {
    @LumiTheme private var theme
    let llmProvider: any LLMProviderManaging
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Model")
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

            // Provider/Model List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(providerViewModels, id: \.providerID) { vm in
                        ProviderModelSection(vm: vm)
                    }
                }
                .padding(8)
            }
        }
        .background(theme.background)
    }

    private var providerViewModels: [ProviderViewModel] {
        llmProvider.allLLMProviders().map { provider in
            let info = type(of: provider).info
            let models = llmProvider.models(for: info.id)
            let isSelectedProvider = info.id == llmProvider.selectedProviderID
            let selectedModel = isSelectedProvider ? llmProvider.selectedModel : nil
            return ProviderViewModel(
                providerID: info.id,
                providerName: info.displayName,
                models: models,
                modelDisplayNames: info.modelDisplayNames,
                isSelectedProvider: isSelectedProvider,
                selectedModel: selectedModel,
                onSelect: { model in
                    llmProvider.selectModel(providerID: info.id, model: model)
                    isPresented = false
                }
            )
        }
    }
}

private struct ProviderViewModel: Identifiable {
    let providerID: String
    let providerName: String
    let models: [String]
    let modelDisplayNames: [String: String]
    let isSelectedProvider: Bool
    let selectedModel: String?
    let onSelect: (String) -> Void

    var id: String { providerID }
}

private struct ProviderModelSection: View {
    @LumiTheme private var theme
    let vm: ProviderViewModel

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(spacing: 4) {
            // Provider header
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 12)
                        .foregroundColor(theme.textTertiary)

                    Text(vm.providerName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textPrimary)

                    if vm.isSelectedProvider {
                        Text("✓")
                            .font(.system(size: 11))
                            .foregroundColor(theme.primary)
                    }

                    Spacer()

                    Text("\(vm.models.count)")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Models
            if isExpanded {
                ForEach(vm.models, id: \.self) { model in
                    let isSelected = vm.isSelectedProvider && model == vm.selectedModel
                    Button {
                        vm.onSelect(model)
                    } label: {
                        HStack {
                            Text("  \(vm.modelDisplayNames[model] ?? model)")
                                .font(.system(size: 12))
                                .foregroundColor(isSelected ? theme.primary : theme.textSecondary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.primary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? theme.primary.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
