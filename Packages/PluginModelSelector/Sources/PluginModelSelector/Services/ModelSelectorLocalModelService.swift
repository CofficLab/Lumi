import Foundation
import LumiCoreKit

public enum ModelSelectorLocalModelService {
    @MainActor
    public static func loadModelInfos(
        providerIds: [String],
        llmVM: AppLLMVM
    ) async -> [String: [LocalModelInfo]] {
        let providers: [(String, any SuperLocalLLMProvider)] = providerIds.compactMap { id in
            guard let provider = llmVM.createProvider(id: id) as? any SuperLocalLLMProvider else { return nil }
            return (id, provider)
        }

        return await withTaskGroup(of: (String, [LocalModelInfo]).self) { group in
            for (id, provider) in providers {
                group.addTask {
                    let infos = await provider.getAvailableModels()
                    return (id, infos)
                }
            }

            var combined: [String: [LocalModelInfo]] = [:]
            for await (id, infos) in group where !infos.isEmpty {
                combined[id] = infos
            }
            return combined
        }
    }
}
