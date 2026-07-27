import SwiftUI
import LLMKit
import LumiKernel

/// 项目问题扫描器模型选择视图
///
/// 允许用户选择模型偏好：自动路由或手动指定模型。
public struct ScannerModelPickerView: View {
    @Binding var preference: ScannerModelPreference

    private let providers: [LLMProviderInfo]

    /// 手动模式下的供应商选择
    @State private var selectedProviderId: String = ""
    /// 手动模式下的模型选择
    @State private var selectedModel: String = ""

    public init(preference: Binding<ScannerModelPreference>, providers: [LLMProviderInfo] = []) {
        self._preference = preference
        self.providers = providers
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 自动/手动切换
            Picker("模型选择", selection: $preference) {
                Text(verbatim: LumiPluginLocalization.string("Auto (自动选择)", bundle: .module)).tag(ScannerModelPreference.auto)
                Text(verbatim: LumiPluginLocalization.string("手动指定", bundle: .module)).tag(ScannerModelPreference.manual(providerId: selectedProviderId, model: selectedModel))
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
                Text(verbatim: LumiPluginLocalization.string("供应商", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("供应商", selection: $selectedProviderId) {
                    Text(verbatim: LumiPluginLocalization.string("请选择", bundle: .module)).tag("")
                    ForEach(providers.filter(\.isEnabled), id: \.id) { provider in
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
                    Text(verbatim: LumiPluginLocalization.string("模型", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("模型", selection: $selectedModel) {
                        Text(verbatim: LumiPluginLocalization.string("请选择", bundle: .module)).tag("")
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
        guard let provider = providers.first(where: { $0.id == selectedProviderId }) else {
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
            if let firstProvider = providers.first(where: \.isEnabled) {
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

}
