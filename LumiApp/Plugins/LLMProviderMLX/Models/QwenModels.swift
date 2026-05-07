import Foundation

/// Qwen 系列模型定义
///
/// 阿里云开源大语言模型系列，中文友好，性价比高
public enum QwenModels {
    
    /// 所有 Qwen 模型列表
    public static let all: [LocalModelInfo] = [
        LocalModelInfo(
            id: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
            displayName: "Qwen 3.5 0.8B OptiQ",
            description: "极小体积，适合入门与低内存设备",
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
            displayName: "Qwen 3.5 4B OptiQ",
            description: "轻量中文模型，OptiQ 量化",
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
            displayName: "Qwen 3.5 9B",
            description: "阿里云最新模型，中文能力强，支持工具调用",
            size: "~6 GB",
            minRAM: 16,
            expectedBytes: 6_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 2,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3.5-14B-4bit",
            displayName: "Qwen 3.5 14B",
            description: "更强的中文模型，适合复杂任务",
            size: "~9 GB",
            minRAM: 24,
            expectedBytes: 9_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 3,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen2-VL-7B-Instruct-4bit",
            displayName: "Qwen2 VL 7B",
            description: "支持图片理解的视觉语言模型",
            size: "~5 GB",
            minRAM: 16,
            expectedBytes: 5_000_000_000,
            supportsVision: true,
            supportsTools: false,
            priority: 10,
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
