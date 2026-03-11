import Foundation

/// 工具展示分类（用于 UI 图标/颜色/类型映射）。
enum ToolPresentationCategory: String, Sendable, Equatable {
    case shell
    case readFile
    case writeFile
    case listDirectory
    case agent
    case unknown
}

/// 工具展示描述符（由插件提供）。
struct ToolPresentationDescriptor: Sendable, Equatable {
    let toolName: String
    let displayName: String
    let emoji: String
    let category: ToolPresentationCategory
    let order: Int
}

/// 工具展示描述符解析器（插件优先，内置回退）。
@MainActor
enum ToolPresentationDescriptorResolver {
    static func descriptor(for toolName: String) -> ToolPresentationDescriptor {
        if let pluginDescriptor = PluginProvider.shared
            .getToolPresentationDescriptors()
            .first(where: { $0.toolName == toolName }) {
            return pluginDescriptor
        }

        return fallbackDescriptor(for: toolName)
    }

    private static func fallbackDescriptor(for toolName: String) -> ToolPresentationDescriptor {
        switch toolName {
        case "run_command", "run_shell_command", "bash":
            return .init(toolName: toolName, displayName: "Shell 命令", emoji: "⚡", category: .shell, order: 0)
        case "read_file":
            return .init(toolName: toolName, displayName: "读取文件", emoji: "📖", category: .readFile, order: 0)
        case "write_file":
            return .init(toolName: toolName, displayName: "写入文件", emoji: "✍️", category: .writeFile, order: 0)
        case "list_directory", "list_files":
            return .init(toolName: toolName, displayName: "列出目录", emoji: "📁", category: .listDirectory, order: 0)
        case "create_and_assign_task", "agent":
            return .init(toolName: toolName, displayName: "智能助手", emoji: "🧩", category: .agent, order: 0)
        default:
            let title = toolName.replacingOccurrences(of: "_", with: " ").capitalized
            return .init(toolName: toolName, displayName: title, emoji: "🔧", category: .unknown, order: 0)
        }
    }
}

