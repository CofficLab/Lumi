import Foundation
import LumiKernel

/// Qwen 系列模型定义
///
/// 阿里云开源大语言模型系列，中文友好，性价比高
public enum QwenModels {
    
    /// 所有 Qwen 模型列表
    public static let all: [LocalModelInfo] = [
        // MARK: - Qwen3 纯文本系列
        
        LocalModelInfo(
            id: "mlx-community/Qwen3-0.6B-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 0.6B", bundle: .module),
            description: LumiPluginLocalization.string("极小体积，适合入门与低内存设备", bundle: .module),
            size: "~0.4 GB",
            minRAM: 4,
            expectedBytes: 400_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 0,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3-1.7B-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 1.7B", bundle: .module),
            description: LumiPluginLocalization.string("轻量级模型，平衡性能与资源", bundle: .module),
            size: "~1.2 GB",
            minRAM: 8,
            expectedBytes: 1_200_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 1,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3-4B-Instruct-2507-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 4B Instruct", bundle: .module),
            description: LumiPluginLocalization.string("指令优化模型，对话能力强", bundle: .module),
            size: "~2.5 GB",
            minRAM: 8,
            expectedBytes: 2_500_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 2,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3-8B-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 8B", bundle: .module),
            description: LumiPluginLocalization.string("中等规模模型，性能均衡", bundle: .module),
            size: "~5 GB",
            minRAM: 16,
            expectedBytes: 5_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 3,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3-14B-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 14B", bundle: .module),
            description: LumiPluginLocalization.string("大规模模型，强大的推理能力", bundle: .module),
            size: "~9 GB",
            minRAM: 16,
            expectedBytes: 9_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 4,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3-30B-A3B-Instruct-2507-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 30B-A3B MoE", bundle: .module),
            description: LumiPluginLocalization.string("MoE 架构，仅激活 3B 参数，性能强劲", bundle: .module),
            size: "~17 GB",
            minRAM: 24,
            expectedBytes: 17_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 5,
            series: "Qwen 系列"
        ),
        
        // MARK: - Qwen3.5 多模态系列
        
        LocalModelInfo(
            id: "mlx-community/Qwen3.5-9B-MLX-4bit",
            displayName: LumiPluginLocalization.string("Qwen3.5 9B", bundle: .module),
            description: LumiPluginLocalization.string("多模态模型，支持图文理解", bundle: .module),
            size: "~6 GB",
            minRAM: 16,
            expectedBytes: 6_000_000_000,
            supportsVision: true,
            supportsTools: true,
            priority: 10,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3.5-27B-Claude-4.6-Opus-Distilled-MLX-4bit",
            displayName: LumiPluginLocalization.string("Qwen3.5 27B Distilled", bundle: .module),
            description: LumiPluginLocalization.string("Claude 蒸馏版，综合能力出众", bundle: .module),
            size: "~16 GB",
            minRAM: 24,
            expectedBytes: 16_000_000_000,
            supportsVision: true,
            supportsTools: true,
            priority: 11,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3.5-122B-A10B-4bit",
            displayName: LumiPluginLocalization.string("Qwen3.5 122B-A10B MoE", bundle: .module),
            description: LumiPluginLocalization.string("旗舰多模态 MoE，仅激活 10B 参数", bundle: .module),
            size: "~70 GB",
            minRAM: 96,
            expectedBytes: 70_000_000_000,
            supportsVision: true,
            supportsTools: true,
            priority: 12,
            series: "Qwen 系列"
        ),
        
        // MARK: - Qwen3.6 多模态系列
        
        LocalModelInfo(
            id: "mlx-community/Qwen3.6-35B-A3B-4bit",
            displayName: LumiPluginLocalization.string("Qwen3.6 35B-A3B", bundle: .module),
            description: LumiPluginLocalization.string("最新多模态 MoE，仅激活 3B 参数", bundle: .module),
            size: "~20 GB",
            minRAM: 24,
            expectedBytes: 20_000_000_000,
            supportsVision: true,
            supportsTools: true,
            priority: 20,
            series: "Qwen 系列"
        ),
        
        // MARK: - Qwen3-VL 视觉语言系列
        
        LocalModelInfo(
            id: "mlx-community/Qwen3-VL-2B-Instruct-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 VL 2B", bundle: .module),
            description: LumiPluginLocalization.string("轻量视觉语言模型，支持图片理解", bundle: .module),
            size: "~1.8 GB",
            minRAM: 8,
            expectedBytes: 1_798_023_774,
            supportsVision: true,
            supportsTools: false,
            priority: 30,
            series: "Qwen 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3-VL-4B-Instruct-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 VL 4B", bundle: .module),
            description: LumiPluginLocalization.string("视觉语言模型，图片理解能力强", bundle: .module),
            size: "~3.1 GB",
            minRAM: 8,
            expectedBytes: 3_109_732_071,
            supportsVision: true,
            supportsTools: false,
            priority: 31,
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
            priority: 32,
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
