import Foundation
import KitLLM

/// The seven provider families shipped by Lumi 5.16.0.
@MainActor
public enum MLXProviderCatalog {
    public static let registrations: [MLXModelRegistration] = [
        .init(id: "mlx-community/Qwen3-0.6B-4bit", displayName: "Qwen3 0.6B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 8),
        .init(id: "mlx-community/Qwen3-1.7B-4bit", displayName: "Qwen3 1.7B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 8),
        .init(id: "mlx-community/Qwen3-4B-Instruct-2507-4bit", displayName: "Qwen3 4B Instruct", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 8),
        .init(id: "mlx-community/Qwen3-8B-4bit", displayName: "Qwen3 8B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 16),
        .init(id: "mlx-community/Qwen3-14B-4bit", displayName: "Qwen3 14B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 16),
        .init(id: "mlx-community/Qwen3-30B-A3B-Instruct-2507-4bit", displayName: "Qwen3 30B-A3B MoE", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 24),
        .init(id: "mlx-community/Qwen3.5-9B-MLX-4bit", displayName: "Qwen3.5 9B", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 16, supportsVision: true),
        .init(id: "mlx-community/Qwen3.5-27B-Claude-4.6-Opus-Distilled-MLX-4bit", displayName: "Qwen3.5 27B Distilled", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 24, supportsVision: true),
        .init(id: "mlx-community/Qwen3.5-122B-A10B-4bit", displayName: "Qwen3.5 122B-A10B MoE", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 96, supportsVision: true),
        .init(id: "mlx-community/Qwen3.6-35B-A3B-4bit", displayName: "Qwen3.6 35B-A3B", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 24, supportsVision: true),
        .init(id: "mlx-community/Qwen3-VL-2B-Instruct-4bit", displayName: "Qwen3 VL 2B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 8, supportsVision: true, supportsTools: false),
        .init(id: "mlx-community/Qwen3-VL-4B-Instruct-4bit", displayName: "Qwen3 VL 4B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 8, supportsVision: true, supportsTools: false),
        .init(id: "mlx-community/Qwen2-VL-7B-Instruct-4bit", displayName: "Qwen2 VL 7B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 16, supportsVision: true, supportsTools: false),
        .init(id: "mlx-community/Llama-3.2-1B-Instruct-4bit", displayName: "Llama 3.2 1B", series: "Llama", providerID: "mlx-llama", minimumRAMGB: 8),
        .init(id: "mlx-community/Llama-3.2-3B-Instruct-4bit", displayName: "Llama 3.2 3B", series: "Llama", providerID: "mlx-llama", minimumRAMGB: 8),
        .init(id: "mlx-community/Llama-3.3-70B-Instruct-4bit", displayName: "Llama 3.3 70B", series: "Llama", providerID: "mlx-llama", contextWindowSize: 131_072, minimumRAMGB: 64),
        .init(id: "mlx-community/Mistral-Nemo-Instruct-2407-4bit", displayName: "Mistral Nemo 12B", series: "Mistral", providerID: "mlx-mistral", minimumRAMGB: 16),
        .init(id: "mlx-community/gemma-4-E2B-it-4bit", displayName: "Gemma 4 E2B Instruct", series: "Gemma", providerID: "mlx-gemma4", minimumRAMGB: 8),
        .init(id: "mlx-community/gemma-4-E4B-it-4bit", displayName: "Gemma 4 E4B Instruct", series: "Gemma", providerID: "mlx-gemma4", minimumRAMGB: 16),
        .init(id: "mlx-community/gemma-4-E2B-4bit", displayName: "Gemma 4 E2B", series: "Gemma", providerID: "mlx-gemma4", minimumRAMGB: 8, supportsTools: false),
        .init(id: "mlx-community/gemma-4-E4B-4bit", displayName: "Gemma 4 E4B", series: "Gemma", providerID: "mlx-gemma4", minimumRAMGB: 16, supportsTools: false),
        .init(id: "mlx-community/gemma-4-26B-A4B-it-4bit", displayName: "Gemma 4 26B-A4B Instruct", series: "Gemma", providerID: "mlx-gemma4", contextWindowSize: 131_072, minimumRAMGB: 32),
        .init(id: "mlx-community/gemma-4-26B-A4B-4bit", displayName: "Gemma 4 26B-A4B", series: "Gemma", providerID: "mlx-gemma4", contextWindowSize: 131_072, minimumRAMGB: 32, supportsVision: true, supportsTools: false),
        .init(id: "mlx-community/gemma-4-31B-it-4bit", displayName: "Gemma 4 31B Instruct", series: "Gemma", providerID: "mlx-gemma4", contextWindowSize: 131_072, minimumRAMGB: 32, supportsVision: true),
        .init(id: "mlx-community/gemma-4-31B-4bit", displayName: "Gemma 4 31B", series: "Gemma", providerID: "mlx-gemma4", contextWindowSize: 131_072, minimumRAMGB: 32, supportsVision: true, supportsTools: false),
        .init(id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit", displayName: "DeepSeek R1 Distill 1.5B", series: "DeepSeek", providerID: "mlx-deepseek", minimumRAMGB: 8),
        .init(id: "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit", displayName: "DeepSeek R1 Distill 7B", series: "DeepSeek", providerID: "mlx-deepseek", minimumRAMGB: 16),
        .init(id: "mlx-community/DeepSeek-R1-Distill-Qwen-14B-4bit", displayName: "DeepSeek R1 Distill 14B", series: "DeepSeek", providerID: "mlx-deepseek", minimumRAMGB: 24),
        .init(id: "mlx-community/Qwen2.5-Coder-3B-Instruct-4bit", displayName: "Qwen2.5 Coder 3B", series: "Coder", providerID: "mlx-coder", minimumRAMGB: 8),
        .init(id: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit", displayName: "Qwen2.5 Coder 7B", series: "Coder", providerID: "mlx-coder", minimumRAMGB: 16),
        .init(id: "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit", displayName: "Qwen3 Coder 30B", series: "Coder", providerID: "mlx-coder", contextWindowSize: 131_072, minimumRAMGB: 32),
        .init(id: "mlx-community/Phi-4-mini-instruct-4bit", displayName: "Phi-4 mini", series: "Microsoft", providerID: "mlx-microsoft", minimumRAMGB: 8),
    ]

    public static func models(for providerID: String) -> [MLXModelRegistration] {
        registrations.filter { $0.providerID == providerID && $0.minimumRAMGB <= systemRAMGB }
    }

    public static var availableRegistrations: [MLXModelRegistration] {
        registrations.filter { $0.minimumRAMGB <= systemRAMGB }
    }

    public static var availableSeries: [String] {
        var result: [String] = []
        for model in availableRegistrations where !result.contains(model.series) {
            result.append(model.series)
        }
        return result
    }

    public static func models(forSeries series: String) -> [MLXModelRegistration] {
        availableRegistrations.filter { $0.series == series }
    }

    public static func makeProviders() -> [any SuperLLMProvider] {
        ["mlx-qwen", "mlx-llama", "mlx-mistral", "mlx-gemma4", "mlx-deepseek", "mlx-coder", "mlx-microsoft"].compactMap { id in
            guard let first = registrations.first(where: { $0.providerID == id }) else { return nil }
            return MLXLocalProvider(providerID: id, name: first.series)
        }
    }

    private static var systemRAMGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
    }
}
