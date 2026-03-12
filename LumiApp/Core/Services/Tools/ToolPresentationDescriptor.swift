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

/// 工具展示描述符解析器（必须由插件提供）。
@MainActor
enum ToolPresentationDescriptorResolver {
    static func descriptor(for toolName: String) -> ToolPresentationDescriptor {
        if let pluginDescriptor = PluginProvider.shared
            .getToolPresentationDescriptors()
            .first(where: { $0.toolName == toolName }) {
            return pluginDescriptor
        }

        fatalError("Missing ToolPresentationDescriptor for tool '\(toolName)'. Plugins must provide a descriptor via PluginProvider.getToolPresentationDescriptors().")
    }
}

