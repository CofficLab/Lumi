import Foundation

/// 插件注册期运行时能力。
///
/// App 层只构造这些通用能力，不按具体插件名配置 bridge。
/// 具体插件在 ``SuperPlugin/configureRuntime(context:)`` 中按需读取并绑定自己的运行时依赖。
@MainActor
public struct PluginRuntimeContext {
    /// 按插件 UI 上下文解析当前窗口对应的编辑器服务。
    ///
    /// LumiCoreKit 不直接依赖 EditorService，因此这里保持类型擦除；
    /// 需要完整 EditorService API 的编辑器插件可在自己的包内强转。
    public let editorServiceProvider: @MainActor (PluginContext) -> AnyObject?

    /// 打开文件能力。
    public let openFile: @MainActor (URL, String?, PluginContext) async -> Void

    /// 当前项目路径能力。
    public let currentProjectPath: @MainActor (PluginContext) -> String?

    /// 当前活跃窗口 ID。
    public let activeWindowId: @MainActor () -> UUID?

    /// 当前编辑器主题 ID。
    public let editorThemeId: @MainActor () -> String

    /// 将文本添加到当前对话。
    public let addToChat: @MainActor (String, PluginContext) -> Void

    /// 选择对话。
    public let selectConversation: @MainActor (UUID, PluginContext) -> Void

    public init(
        editorServiceProvider: @escaping @MainActor (PluginContext) -> AnyObject? = { _ in nil },
        openFile: @escaping @MainActor (URL, String?, PluginContext) async -> Void = { _, _, _ in },
        currentProjectPath: @escaping @MainActor (PluginContext) -> String? = { context in
            context.currentProjectPath.isEmpty ? nil : context.currentProjectPath
        },
        activeWindowId: @escaping @MainActor () -> UUID? = { nil },
        editorThemeId: @escaping @MainActor () -> String = { "xcode-dark" },
        addToChat: @escaping @MainActor (String, PluginContext) -> Void = { _, _ in },
        selectConversation: @escaping @MainActor (UUID, PluginContext) -> Void = { _, _ in }
    ) {
        self.editorServiceProvider = editorServiceProvider
        self.openFile = openFile
        self.currentProjectPath = currentProjectPath
        self.activeWindowId = activeWindowId
        self.editorThemeId = editorThemeId
        self.addToChat = addToChat
        self.selectConversation = selectConversation
    }
}
