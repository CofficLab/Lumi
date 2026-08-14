import KernelLumi
import LumiUI
import SwiftUI

struct AddCustomProviderSheet: View {
    let kernel: KernelLumi
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var id = ""
    @State private var protocolType: CustomProviderProtocol = .openAI
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var modelsText = ""
    @State private var defaultModel = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("添加云服务商").font(.title2.bold())
                    Text("填写协议和模型信息后即可在当前页面使用").font(.appCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }
            }
            Form {
                Section("供应商") {
                    TextField("名称", text: $name)
                    TextField("唯一 ID（如 my-provider）", text: $id)
                    Picker("协议", selection: $protocolType) {
                        ForEach(CustomProviderProtocol.allCases) { Text($0.title).tag($0) }
                    }
                    TextField("Base URL", text: $baseURL)
                    SecureField("API Key", text: $apiKey)
                }
                Section("模型") {
                    TextField("模型 ID（每行一个）", text: $modelsText, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("默认模型 ID（可选）", text: $defaultModel)
                }
            }
            if let errorMessage {
                Text(errorMessage).font(.appCaption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("保存供应商") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560, height: 560)
        .onAppear { if baseURL.isEmpty { baseURL = protocolType.defaultPath } }
    }

    private func save() {
        let modelIDs = modelsText
            .components(separatedBy: .newlines)
            .flatMap { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
            .filter { !$0.isEmpty }
        let configuration = CustomProviderConfiguration(
            id: id, name: name, protocolType: protocolType, baseURL: baseURL,
            models: modelIDs.map { CustomModelConfiguration(id: $0) }, defaultModel: defaultModel
        )
        do {
            let validated = try configuration.validated()
            guard let manager = kernel.resolveService((any LLMProviderManaging).self) as? LLMProviderManager else {
                throw CustomProviderConfiguration.ValidationError.missingName
            }
            let current = CustomProviderStore.shared.load().filter { $0.id != validated.id } + [validated]
            CustomProviderStore.shared.save(current)
            try manager.registerCustomProvider(validated)
            if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                CustomProviderStore.shared.saveAPIKey(apiKey, for: validated)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
