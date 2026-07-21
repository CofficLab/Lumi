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
            ModelSelectorPopoverContent(llmProvider: llmProvider, isPresented: $isPopoverPresented)
                .frame(width: 600, height: 400)
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

// MARK: - Model Selector Popover Content

private struct ModelSelectorPopoverContent: View {
    @LumiTheme private var theme
    let llmProvider: any LLMProviderManaging
    @Binding var isPresented: Bool

    @State private var selectedProviderID: String?
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            // Left: Provider List
            providerList
                .frame(width: 200)

            Divider()

            // Right: Model List for selected provider
            modelList
        }
        .frame(width: 600, height: 400)
        .onAppear {
            // Select current provider or first available
            if selectedProviderID == nil {
                selectedProviderID = llmProvider.selectedProviderID
                    ?? llmProvider.allLLMProviders().first.map { type(of: $0).info.id }
            }
        }
    }

    // MARK: - Provider List

    private var providerList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Providers")
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

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
                TextField("Search providers", text: $searchText)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.surface.opacity(0.5))

            Divider()

            // Provider items
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredProviders, id: \.id) { info in
                        ProviderListItem(
                            info: info,
                            isSelected: info.id == selectedProviderID,
                            onSelect: {
                                selectedProviderID = info.id
                            }
                        )
                    }
                }
                .padding(8)
            }
        }
        .background(theme.background)
    }

    private var filteredProviders: [LumiLLMProviderInfo] {
        let providers = llmProvider.allLLMProviders().map { type(of: $0).info }
        if searchText.isEmpty {
            return providers
        }
        return providers.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Model List

    private var modelList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let providerID = selectedProviderID,
                   let provider = llmProvider.allLLMProviders().first(where: { type(of: $0).info.id == providerID }) {
                    let info = type(of: provider).info
                    Text(info.displayName)
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    Text("Models")
                        .font(.system(size: 13, weight: .semibold))
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.surface)

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
                TextField("Search models", text: $searchText)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.surface.opacity(0.5))

            Divider()

            // Model items
            if let providerID = selectedProviderID {
                let models = llmProvider.models(for: providerID)
                let filteredModels = searchText.isEmpty ? models : models.filter {
                    $0.localizedCaseInsensitiveContains(searchText)
                }

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredModels, id: \.self) { model in
                            let info = llmProvider.allLLMProviders()
                                .first { type(of: $0).info.id == providerID }.map { type(of: $0).info }
                            let displayName = info?.modelDisplayNames[model] ?? model
                            let isSelected = model == llmProvider.selectedModel

                            Button {
                                llmProvider.selectModel(providerID: providerID, model: model)
                                isPresented = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(displayName)
                                            .font(.system(size: 13))
                                            .foregroundColor(isSelected ? theme.primary : theme.textPrimary)

                                        Text(model)
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
                    .padding(8)
                }
            } else {
                Spacer()
                Text("Select a provider")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textTertiary)
                Spacer()
            }
        }
        .background(theme.background)
    }
}

// MARK: - Provider List Item

private struct ProviderListItem: View {
    @LumiTheme private var theme
    let info: LumiLLMProviderInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? theme.primary : theme.textPrimary)

                    Text("\(info.availableModels.count) models")
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
