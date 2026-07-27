import Foundation
import LumiKernel

/// Qwen 系列模型定义
///
/// 阿里云开源大语言模型系列，中文友好，性价比高
public enum QwenModels {
    
    /// 所有 Qwen 模型列表
    public static let all: [LocalModelInfo] = [
        LocalModelInfo(
            id: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
            displayName: LumiPluginLocalization.string("Qwen 3.5 0.8B OptiQ", bundle: .module),
            description: LumiPluginLocalization.string("极小体积，适合入门与低内存设备", bundle: .module),
            size: "~0.6 GB",
            minRAM: 4,
            expectedBytes: 600_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 0,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3.5-4B-OptiQ-4bit",
            displayName: LumiPluginLocalization.string("Qwen 3.5 4B OptiQ", bundle: .module),
            description: LumiPluginLocalization.string("轻量中文模型，OptiQ 量化", bundle: .module),
            size: "~2.5 GB",
            minRAM: 8,
            expectedBytes: 2_500_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 1,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3.5-9B-4bit",
            displayName: LumiPluginLocalization.string("Qwen 3.5 9B", bundle: .module),
            description: LumiPluginLocalization.string("阿里云最新模型，中文能力强，支持工具调用", bundle: .module),
            size: "~6 GB",
            minRAM: 16,
            expectedBytes: 6_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 2,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3-VL-2B-Instruct-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 VL 2B", bundle: .module),
            description: LumiPluginLocalization.string("新一代轻量视觉语言模型，支持图片理解", bundle: .module),
            size: "~1.8 GB",
            minRAM: 8,
            expectedBytes: 1_798_023_774,
            supportsVision: true,
            supportsTools: false,
            priority: 9,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3-VL-4B-Instruct-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 VL 4B", bundle: .module),
            description: LumiPluginLocalization.string("新一代视觉语言模型，图片理解能力强", bundle: .module),
            size: "~3.1 GB",
            minRAM: 8,
            expectedBytes: 3_109_732_071,
            supportsVision: true,
            supportsTools: false,
            priority: 10,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen2-VL-7B-Instruct-4bit",
            displayName: LumiPluginLocalization.string("Qwen2 VL 7B", bundle: .module),
            description: LumiPluginLocalization.string("支持图片理解的视觉语言模型", bundle: .module),
            size: "~5 GB",
            minRAM: 16,
            expectedBytes: 5_000_000_000,
            supportsVision: true,
            supportsTools: false,
            priority: 11,
            series: "Qwen 系列"
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
