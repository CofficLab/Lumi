/// 已弃用：使用 PluginContext.supportsAIChat 替代
///
/// 此类型不再被任何插件引用。ViewContainer 是否支持 AI 聊天
/// 现在由 ViewContainerItem.supportsAIChat 声明，
/// 通过 PluginContext.supportsAIChat 传递给消费端插件。
@available(*, deprecated, message: "Use PluginContext.supportsAIChat instead")
public enum ChatSurfaceActivation {
    @available(*, deprecated, message: "Use PluginContext.supportsAIChat instead")
    public static func isActive(_ activeIcon: String?) -> Bool {
        false
    }
}
