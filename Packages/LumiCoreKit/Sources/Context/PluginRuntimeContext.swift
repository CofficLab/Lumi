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

    /// 按文件路径打开文件能力。
    public let openFilePath: @MainActor (String, UUID?) -> Void

    /// 当前项目路径能力。
    public let currentProjectPath: @MainActor (PluginContext) -> String?

    /// 当前活跃窗口 ID。
    public let activeWindowId: @MainActor () -> UUID?

    /// 当前编辑器主题 ID。
    public let editorThemeId: @MainActor () -> String

    /// 是否显示助手消息头部。
    public let showsAssistantHeader: @MainActor () -> Bool

    /// 注册编辑器文本输入安装器。
    ///
    /// LumiCoreKit 不直接依赖 EditorService/CodeEditTextView，因此使用类型擦除。
    /// 具体编辑器插件可在自己的包内强转为需要的宿主类型。
    public let registerEditorTextInputInstaller: @MainActor (@escaping @MainActor (AnyObject, AnyObject) -> Void) -> Void

    /// 应用编辑器字体名称。
    public let applyEditorFontName: @MainActor (String?, PluginContext) -> Void

    /// 插件数据库根目录。
    public let databaseDirectory: @Sendable () -> URL

    /// 将用户消息入队。
    public let enqueueUserMessage: @MainActor (ChatMessage, TurnFinishedContext) -> Void

    /// 将文本添加到当前对话。
    public let addToChat: @MainActor (String, PluginContext) -> Void

    /// 选择对话。
    public let selectConversation: @MainActor (UUID, PluginContext) -> Void

    /// 注册空闲时间快照提供器。
    public let registerIdleTimeSnapshotProvider: @MainActor (@escaping IdleTimeSnapshotProviderClosure) -> Void

    public init(
        editorServiceProvider: @escaping @MainActor (PluginContext) -> AnyObject? = { _ in nil },
        openFile: @escaping @MainActor (URL, String?, PluginContext) async -> Void = { _, _, _ in },
        openFilePath: @escaping @MainActor (String, UUID?) -> Void = { _, _ in },
        currentProjectPath: @escaping @MainActor (PluginContext) -> String? = { context in
            context.currentProjectPath.isEmpty ? nil : context.currentProjectPath
        },
        activeWindowId: @escaping @MainActor () -> UUID? = { nil },
        editorThemeId: @escaping @MainActor () -> String = { "xcode-dark" },
        showsAssistantHeader: @escaping @MainActor () -> Bool = { false },
        registerEditorTextInputInstaller: @escaping @MainActor (@escaping @MainActor (AnyObject, AnyObject) -> Void) -> Void = { _ in },
        applyEditorFontName: @escaping @MainActor (String?, PluginContext) -> Void = { _, _ in },
        databaseDirectory: @escaping @Sendable () -> URL = {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
            return appSupport.appendingPathComponent(bundleID, isDirectory: true)
                .appendingPathComponent("db", isDirectory: true)
        },
        enqueueUserMessage: @escaping @MainActor (ChatMessage, TurnFinishedContext) -> Void = { _, _ in },
        addToChat: @escaping @MainActor (String, PluginContext) -> Void = { _, _ in },
        selectConversation: @escaping @MainActor (UUID, PluginContext) -> Void = { _, _ in },
        registerIdleTimeSnapshotProvider: @escaping @MainActor (@escaping IdleTimeSnapshotProviderClosure) -> Void = { _ in }
    ) {
        self.editorServiceProvider = editorServiceProvider
        self.openFile = openFile
        self.openFilePath = openFilePath
        self.currentProjectPath = currentProjectPath
        self.activeWindowId = activeWindowId
        self.editorThemeId = editorThemeId
        self.showsAssistantHeader = showsAssistantHeader
        self.registerEditorTextInputInstaller = registerEditorTextInputInstaller
        self.applyEditorFontName = applyEditorFontName
        self.databaseDirectory = databaseDirectory
        self.enqueueUserMessage = enqueueUserMessage
        self.addToChat = addToChat
        self.selectConversation = selectConversation
        self.registerIdleTimeSnapshotProvider = registerIdleTimeSnapshotProvider
    }
}
