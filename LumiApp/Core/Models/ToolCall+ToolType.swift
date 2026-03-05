import Foundation

// MARK: - Tool Type Mapping

extension ToolCall {
    /// 根据工具名称推断工具类型
    var toolType: ToolOutputView.ToolType {
        switch name {
        // Shell 工具
        case "run_shell_command":
            return .shell

        // 文件读写工具
        case "read_file":
            return .readFile
        case "write_file":
            return .writeFile

        // 目录操作工具
        case "list_directory", "list_files":
            return .listDirectory

        // Agent 工具
        case "agent":
            return .agent

        // 未知工具
        default:
            return .unknown
        }
    }

    /// 工具显示名称
    var displayName: String {
        switch name {
        case "run_shell_command":
            return "Shell 命令"
        case "read_file":
            return "读取文件"
        case "write_file":
            return "写入文件"
        case "list_directory", "list_files":
            return "列出目录"
        case "agent":
            return "智能助手"
        default:
            return name.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - ChatMessage Extension

extension ChatMessage {
    /// 获取关联的工具类型
    var toolType: ToolOutputView.ToolType? {
        guard let toolCalls = toolCalls, let firstTool = toolCalls.first else {
            return nil
        }
        return firstTool.toolType
    }

    /// 获取关联的工具显示名称
    var toolDisplayName: String? {
        guard let toolCalls = toolCalls, let firstTool = toolCalls.first else {
            return nil
        }
        return firstTool.displayName
    }
}
