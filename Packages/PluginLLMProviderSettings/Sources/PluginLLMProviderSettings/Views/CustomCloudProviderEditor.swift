import KitLLM
import SwiftUI

/// 新增或编辑用户自定义云端供应商。
@MainActor
struct CustomCloudProviderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store: UserDefinedCloudProviderStore

    private let existingConfiguration: UserDefinedCloudProviderConfiguration?

    @State private var displayName: String
    @State private var description: String
    @State private var baseURL: String
    @State private var apiFormat: LLMProviderAPIFormat
    @State private var defaultModel: String
    @State private var modelIDs: String
    @State private var websiteURL: String
    @State private var errorMessage: String?

    init(
        store: UserDefinedCloudProviderStore,
        configuration: UserDefinedCloudProviderConfiguration? = nil
    ) {
        self._store = ObservedObject(wrappedValue: store)
        self.existingConfiguration = configuration
        self._displayName = State(initialValue: configuration?.displayName ?? "")
        self._description = State(initialValue: configuration?.description ?? "")
        self._baseURL = State(initialValue: configuration?.baseURL ?? "")
        self._apiFormat = State(initialValue: configuration?.apiFormat ?? .openAI)
        self._defaultModel = State(initialValue: configuration?.defaultModel ?? "")
        self._modelIDs = State(initialValue: configuration?.models.map(\.id).joined(separator: "\n") ?? "")
        self._websiteURL = State(initialValue: configuration?.websiteURLString ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(existingConfiguration == nil ? "添加云端供应商" : "编辑云端供应商")
                        .font(.title2.weight(.semibold))
                    Text("配置兼容的 API 端点和模型列表")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section("基本信息") {
                    TextField("供应商名称", text: $displayName)
                    TextField("描述（可选）", text: $description)
                    TextField("官网（可选）", text: $websiteURL)
                }

                Section("连接") {
                    TextField("API Endpoint URL", text: $baseURL)
                        .textContentType(.URL)
                    Picker("API 格式", selection: $apiFormat) {
                        Text("OpenAI 兼容").tag(LLMProviderAPIFormat.openAI)
                        Text("Anthropic 兼容").tag(LLMProviderAPIFormat.anthropic)
                        Text("OpenAI Responses").tag(LLMProviderAPIFormat.responses)
                    }
                }

                Section("模型") {
                    TextField("默认模型 ID", text: $defaultModel)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("模型 ID（每行一个）")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $modelIDs)
                            .font(.body.monospaced())
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
    }

    private func save() {
        let ids = modelIDs
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let oldModels = Dictionary(uniqueKeysWithValues: (existingConfiguration?.models ?? []).map { ($0.id, $0) })
        let models = ids.map { id in
            oldModels[id] ?? UserDefinedCloudModel(id: id)
        }
        let resolvedDefaultModel = defaultModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (models.first?.id ?? "")
            : defaultModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let configuration = UserDefinedCloudProviderConfiguration(
            id: existingConfiguration?.id ?? "user-\(UUID().uuidString.lowercased())",
            displayName: displayName,
            description: description,
            baseURL: baseURL,
            apiFormat: apiFormat,
            defaultModel: resolvedDefaultModel,
            models: models,
            websiteURLString: websiteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : websiteURL
        )

        do {
            try store.upsert(configuration)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
