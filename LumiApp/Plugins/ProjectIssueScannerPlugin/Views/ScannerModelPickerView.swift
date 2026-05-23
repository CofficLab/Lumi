import SwiftUI

/// 项目问题扫描器模型选择视图
///
/// 允许用户选择模型偏好：自动路由或手动指定模型。
struct ScannerModelPickerView: View {
    @EnvironmentObject private var llmVM: AppLLMVM

    @Binding var preference: ScannerModelPreference

    /// 手动模式下的供应商选择
    @State private var selectedProviderId: String = ""
    /// 手动模式下的模型选择
    @State private var selectedModel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 自动/手动切换
            Picker("模型选择", selection: $preference) {
                Text("Auto (自动选择)").tag(ScannerModelPreference.auto)
                Text("手动指定").tag(ScannerModelPreference.manual(providerId: selectedProviderId, model: selectedModel))
            }
            .pickerStyle(.segmented)

            // 手动模式下的详细选择
            if isManualMode {
                manualSelectionView
            }
        }
        .onAppear {
            loadManualSelection()
        }
    }

    // MARK: - Subviews

    private var manualSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 供应商选择
            VStack(alignment: .leading, spacing: 4) {
                Text("供应商")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("供应商", selection: $selectedProviderId) {
                    Text("请选择").tag("")
                    ForEach(llmVM.availableProviders.filter(\.isEnabled), id: \.id) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }
                .onChange(of: selectedProviderId) { _, _ in
                    updateModelIfNeeded()
                }
            }

            // 模型选择
            if !selectedProviderId.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("模型")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("模型", selection: $selectedModel) {
                        Text("请选择").tag("")
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: selectedModel) { _, newModel in
                        updatePreference()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var isManualMode: Bool {
        if case .manual = preference {
            return true
        }
        return false
    }

    private var availableModels: [String] {
        guard let provider = llmVM.availableProviders.first(where: { $0.id == selectedProviderId }) else {
            return []
        }
        return provider.availableModels
    }

    private func loadManualSelection() {
        if case .manual(let providerId, let model) = preference {
            selectedProviderId = providerId
            selectedModel = model
        } else {
            // 默认选第一个有 API Key 的供应商
            if let firstProvider = llmVM.availableProviders.first(where: { $0.isEnabled && hasApiKey($0.id) }) {
                selectedProviderId = firstProvider.id
                selectedModel = firstProvider.defaultModel
            }
        }
    }

    private func updateModelIfNeeded() {
        guard !selectedProviderId.isEmpty else { return }

        let models = availableModels
        if !models.contains(selectedModel) {
            selectedModel = models.first ?? ""
        }

        updatePreference()
    }

    private func updatePreference() {
        guard !selectedProviderId.isEmpty, !selectedModel.isEmpty else { return }
        preference = .manual(providerId: selectedProviderId, model: selectedModel)
    }

    private func hasApiKey(_ providerId: String) -> Bool {
        guard let providerType = llmVM.providerType(forId: providerId) else { return false }
        let apiKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""
        return !apiKey.isEmpty
    }
}
