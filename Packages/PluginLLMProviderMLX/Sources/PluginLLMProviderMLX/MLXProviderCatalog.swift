import Foundation
import KitLLM

/// 供应商族与模型清单。模型均来自 `mlx-community`，且架构由当前
/// `mlx-swift-lm` 版本支持（DeepSeek-V4、Kimi K2.5 等自定义架构不在其中）。
@MainActor
public enum MLXProviderCatalog {
    public static let registrations: [MLXModelRegistration] = [
        .init(
            id: "mlx-community/Qwen3-0.6B-4bit",
            displayName: "Qwen3 0.6B",
            series: "Qwen",
            providerID: "mlx-qwen",
            minimumRAMGB: 8, downloadSizeBytes: 351_386_061
        ),
        .init(id: "mlx-community/Qwen3-1.7B-4bit", displayName: "Qwen3 1.7B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 8, downloadSizeBytes: 984_015_687),
        .init(id: "mlx-community/Qwen3-4B-Instruct-2507-4bit", displayName: "Qwen3 4B Instruct", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 8, downloadSizeBytes: 2_278_972_236),
        .init(id: "mlx-community/Qwen3-8B-4bit", displayName: "Qwen3 8B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 16, downloadSizeBytes: 4_623_784_971),
        .init(id: "mlx-community/Qwen3-14B-4bit", displayName: "Qwen3 14B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 16, downloadSizeBytes: 8_323_870_520),
        .init(id: "mlx-community/Qwen3-30B-A3B-Instruct-2507-4bit", displayName: "Qwen3 30B-A3B MoE", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 24, downloadSizeBytes: 17_197_087_380),
        .init(id: "mlx-community/Qwen3.5-9B-MLX-4bit", displayName: "Qwen3.5 9B", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 16, downloadSizeBytes: 5_977_074_591, supportsVision: true),
        .init(id: "mlx-community/Qwen3.5-27B-Claude-4.6-Opus-Distilled-MLX-4bit", displayName: "Qwen3.5 27B Distilled", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 24, downloadSizeBytes: 15_153_239_697, supportsVision: true),
        .init(id: "mlx-community/Qwen3.5-122B-A10B-4bit", displayName: "Qwen3.5 122B-A10B MoE", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 96, downloadSizeBytes: 69_620_619_709, supportsVision: true),
        .init(id: "mlx-community/Qwen3.6-35B-A3B-4bit", displayName: "Qwen3.6 35B-A3B", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 24, downloadSizeBytes: 20_429_169_263, supportsVision: true),
        .init(id: "mlx-community/Qwen3-VL-2B-Instruct-4bit", displayName: "Qwen3 VL 2B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 8, downloadSizeBytes: 1_798_023_774, supportsVision: true, supportsTools: false),
        .init(id: "mlx-community/Qwen3-VL-4B-Instruct-4bit", displayName: "Qwen3 VL 4B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 8, downloadSizeBytes: 3_109_732_071, supportsVision: true, supportsTools: false),
        .init(id: "mlx-community/Qwen2-VL-7B-Instruct-4bit", displayName: "Qwen2 VL 7B", series: "Qwen", providerID: "mlx-qwen", minimumRAMGB: 16, downloadSizeBytes: 4_683_476_706, supportsVision: true, supportsTools: false),
        .init(id: "mlx-community/Qwen3.5-0.8B-4bit", displayName: "Qwen3.5 0.8B", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 8, downloadSizeBytes: 652_029_391, supportsVision: true),
        .init(id: "mlx-community/Qwen3.5-4B-MLX-4bit", displayName: "Qwen3.5 4B", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 8, downloadSizeBytes: 3_061_132_920, supportsVision: true),
        .init(id: "mlx-community/Qwen3.6-27B-4bit", displayName: "Qwen3.6 27B", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 24, downloadSizeBytes: 16_081_490_064, supportsVision: true),
        .init(id: "mlx-community/Qwen3.8-27B-4bit", displayName: "Qwen3.8 27B", series: "Qwen", providerID: "mlx-qwen", contextWindowSize: 131_072, minimumRAMGB: 24, downloadSizeBytes: 16_074_310_928, supportsVision: true),
        .init(id: "mlx-community/Llama-3.2-1B-Instruct-4bit", displayName: "Llama 3.2 1B", series: "Llama", providerID: "mlx-llama", minimumRAMGB: 8, downloadSizeBytes: 712_593_855),
        .init(id: "mlx-community/Llama-3.2-3B-Instruct-4bit", displayName: "Llama 3.2 3B", series: "Llama", providerID: "mlx-llama", minimumRAMGB: 8, downloadSizeBytes: 1_824_825_759),
        .init(id: "mlx-community/Llama-3.3-70B-Instruct-4bit", displayName: "Llama 3.3 70B", series: "Llama", providerID: "mlx-llama", contextWindowSize: 131_072, minimumRAMGB: 64, downloadSizeBytes: 39_706_010_909),
        .init(id: "mlx-community/Mistral-Nemo-Instruct-2407-4bit", displayName: "Mistral Nemo 12B", series: "Mistral", providerID: "mlx-mistral", minimumRAMGB: 16, downloadSizeBytes: 6_905_203_123),
        .init(id: "mlx-community/Ministral-3-3B-Instruct-2512-4bit", displayName: "Ministral 3 3B", series: "Mistral", providerID: "mlx-mistral", contextWindowSize: 131_072, minimumRAMGB: 8, downloadSizeBytes: 2_779_152_776),
        .init(id: "mlx-community/Ministral-3-8B-Instruct-2512-4bit", displayName: "Ministral 3 8B", series: "Mistral", providerID: "mlx-mistral", contextWindowSize: 131_072, minimumRAMGB: 16, downloadSizeBytes: 5_630_654_690),
        .init(id: "mlx-community/Ministral-3-14B-Instruct-2512-4bit", displayName: "Ministral 3 14B", series: "Mistral", providerID: "mlx-mistral", contextWindowSize: 131_072, minimumRAMGB: 24, downloadSizeBytes: 8_458_567_190),
        .init(id: "mlx-community/Devstral-Small-2-24B-Instruct-2512-4bit", displayName: "Devstral Small 2 24B", series: "Mistral", providerID: "mlx-mistral", contextWindowSize: 131_072, minimumRAMGB: 24, downloadSizeBytes: 15_136_819_784),
        .init(id: "mlx-community/gemma-4-E2B-it-4bit", displayName: "Gemma 4 E2B Instruct", series: "Gemma", providerID: "mlx-gemma4", minimumRAMGB: 8, downloadSizeBytes: 3_583_088_661),
        .init(id: "mlx-community/gemma-4-E4B-it-4bit", displayName: "Gemma 4 E4B Instruct", series: "Gemma", providerID: "mlx-gemma4", minimumRAMGB: 16, downloadSizeBytes: 5_179_241_512),
        .init(id: "mlx-community/gemma-4-E2B-4bit", displayName: "Gemma 4 E2B", series: "Gemma", providerID: "mlx-gemma4", minimumRAMGB: 8, downloadSizeBytes: 3_613_513_088, supportsTools: false),
        .init(id: "mlx-community/gemma-4-E4B-4bit", displayName: "Gemma 4 E4B", series: "Gemma", providerID: "mlx-gemma4", minimumRAMGB: 16, downloadSizeBytes: 5_249_794_027, supportsTools: false),
        .init(id: "mlx-community/gemma-4-12B-4bit", displayName: "Gemma 4 12B", series: "Gemma", providerID: "mlx-gemma4", contextWindowSize: 131_072, minimumRAMGB: 16, downloadSizeBytes: 11_020_122_837, supportsVision: true),
        .init(id: "mlx-community/gemma-4-26B-A4B-it-4bit", displayName: "Gemma 4 26B-A4B Instruct", series: "Gemma", providerID: "mlx-gemma4", contextWindowSize: 131_072, minimumRAMGB: 32, downloadSizeBytes: 15_373_588_575),
        .init(id: "mlx-community/gemma-4-26B-A4B-4bit", displayName: "Gemma 4 26B-A4B", series: "Gemma", providerID: "mlx-gemma4", contextWindowSize: 131_072, minimumRAMGB: 32, downloadSizeBytes: 15_641_223_519, supportsVision: true, supportsTools: false),
        .init(id: "mlx-community/gemma-4-31B-it-4bit", displayName: "Gemma 4 31B Instruct", series: "Gemma", providerID: "mlx-gemma4", contextWindowSize: 131_072, minimumRAMGB: 32, downloadSizeBytes: 18_444_421_751, supportsVision: true),
        .init(id: "mlx-community/gemma-4-31B-4bit", displayName: "Gemma 4 31B", series: "Gemma", providerID: "mlx-gemma4", contextWindowSize: 131_072, minimumRAMGB: 32, downloadSizeBytes: 18_444_401_973, supportsVision: true, supportsTools: false),
        .init(id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit", displayName: "DeepSeek R1 Distill 1.5B", series: "DeepSeek", providerID: "mlx-deepseek", minimumRAMGB: 8, downloadSizeBytes: 1_011_386_803),
        .init(id: "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit", displayName: "DeepSeek R1 Distill 7B", series: "DeepSeek", providerID: "mlx-deepseek", minimumRAMGB: 16, downloadSizeBytes: 4_295_831_322),
        .init(id: "mlx-community/DeepSeek-R1-Distill-Qwen-14B-4bit", displayName: "DeepSeek R1 Distill 14B", series: "DeepSeek", providerID: "mlx-deepseek", minimumRAMGB: 24, downloadSizeBytes: 8_321_034_914),
        .init(id: "mlx-community/Qwen2.5-Coder-3B-Instruct-4bit", displayName: "Qwen2.5 Coder 3B", series: "Coder", providerID: "mlx-coder", minimumRAMGB: 8, downloadSizeBytes: 1_747_851_791),
        .init(id: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit", displayName: "Qwen2.5 Coder 7B", series: "Coder", providerID: "mlx-coder", minimumRAMGB: 16, downloadSizeBytes: 4_295_890_004),
        .init(id: "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit", displayName: "Qwen3 Coder 30B", series: "Coder", providerID: "mlx-coder", contextWindowSize: 131_072, minimumRAMGB: 32, downloadSizeBytes: 17_197_118_924),
        .init(id: "mlx-community/KAT-Coder-V2.5-Dev-OptiQ-4bit", displayName: "KAT Coder V2.5 Dev", series: "Coder", providerID: "mlx-coder", contextWindowSize: 131_072, minimumRAMGB: 32, downloadSizeBytes: 21_950_414_969),
        .init(id: "mlx-community/Phi-4-mini-instruct-4bit", displayName: "Phi-4 mini", series: "Microsoft", providerID: "mlx-microsoft", minimumRAMGB: 8, downloadSizeBytes: 2_180_067_259),
        .init(id: "mlx-community/gpt-oss-20b-MXFP4-Q8", displayName: "GPT-OSS 20B", series: "GPT-OSS", providerID: "mlx-gptoss", contextWindowSize: 131_072, minimumRAMGB: 24, downloadSizeBytes: 12_104_218_243),
        .init(id: "mlx-community/GLM-4.7-Flash-4bit", displayName: "GLM 4.7 Flash", series: "GLM", providerID: "mlx-glm", contextWindowSize: 131_072, minimumRAMGB: 32, downloadSizeBytes: 16_872_850_407),
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

    private static var systemRAMGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
    }
}
