import Foundation
import LumiKernel

/// DeepSeek 推理模型系列定义
///
/// DeepSeek-R1 蒸馏系列，擅长深度思考与推理任务
public enum DeepSeekModels {

    /// 所有 DeepSeek 模型列表
    public static let all: [LocalModelInfo] = [
        LocalModelInfo(
            id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit",
            displayName: LumiPluginLocalization.string("DeepSeek R1 Distill 1.5B", bundle: .module),
            description: LumiPluginLocalization.string("超轻量推理模型，适合入门体验思维链", bundle: .module),
            size: "~1.0 GB",
            minRAM: 4,
            expectedBytes: 1_011_386_803,
            supportsVision: false,
            supportsTools: false,
            priority: 40,
            series: "DeepSeek 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit",
            displayName: LumiPluginLocalization.string("DeepSeek R1 Distill 7B", bundle: .module),
            description: LumiPluginLocalization.string("中等规模推理模型，擅长数学与逻辑", bundle: .module),
            size: "~4.3 GB",
            minRAM: 16,
            expectedBytes: 4_295_831_322,
            supportsVision: false,
            supportsTools: false,
            priority: 41,
            series: "DeepSeek 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/DeepSeek-R1-Distill-Qwen-14B-4bit",
            displayName: LumiPluginLocalization.string("DeepSeek R1 Distill 14B", bundle: .module),
            description: LumiPluginLocalization.string("大型推理模型，深度思考能力强", bundle: .module),
            size: "~8.3 GB",
            minRAM: 24,
            expectedBytes: 8_321_034_914,
            supportsVision: false,
            supportsTools: false,
            priority: 42,
            series: "DeepSeek 系列"
        ),
    ]

    /// 获取支持视觉的模型
    public static var visionModels: [LocalModelInfo] { all.filter { $0.supportsVision } }

    /// 获取支持工具调用的模型
    public static var toolModels: [LocalModelInfo] { all.filter { $0.supportsTools } }

    /// 根据 ID 查找模型
    public static func model(id: String) -> LocalModelInfo? {
        all.first { $0.id == id }
    }

    /// 根据内存要求过滤可用模型
    public static func availableModels(for systemRAM: Int) -> [LocalModelInfo] {
        all.filter { $0.minRAM <= systemRAM }
    }
}
