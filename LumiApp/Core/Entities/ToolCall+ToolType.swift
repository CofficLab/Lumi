import Foundation

// MARK: - Tool Type Mapping

extension ToolCall {
    /// 根据工具名称推断工具类型
    @MainActor
    var toolType: ToolOutputView.ToolType {
        let descriptor = ToolPresentationDescriptorResolver.descriptor(for: name)
        switch descriptor.category {
        case .shell: return .shell
        case .readFile: return .readFile
        case .writeFile: return .writeFile
        case .listDirectory: return .listDirectory
        case .agent: return .agent
        case .unknown: return .unknown
        }
    }

    /// 工具显示名称
    @MainActor
    var displayName: String {
        ToolPresentationDescriptorResolver.descriptor(for: name).displayName
    }
}

// MARK: - ChatMessage Extension

extension ChatMessage {
    /// 获取关联的工具类型
    @MainActor
    var toolType: ToolOutputView.ToolType? {
        guard let toolCalls = toolCalls, let firstTool = toolCalls.first else {
            return nil
        }
        return firstTool.toolType
    }

    /// 获取关联的工具显示名称
    @MainActor
    var toolDisplayName: String? {
        guard let toolCalls = toolCalls, let firstTool = toolCalls.first else {
            return nil
        }
        return firstTool.displayName
    }
}
