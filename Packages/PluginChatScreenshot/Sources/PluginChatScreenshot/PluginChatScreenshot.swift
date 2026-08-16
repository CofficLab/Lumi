import KernelCore
import ProviderChatSection

/// Chat Screenshot Plugin（KernelCore 版本）
///
/// 由旧版 `Plugins/ChatScreenshotPlugin`（KernelLumi / LumiPlugin 架构）复刻而来：
/// - 在 Chat 分区 Action Bar 的 leading 位置注册「截图」按钮（📷）；
/// - 点击后检查屏幕录制权限 → 全屏抓取 → 遮罩拖选 → 裁剪缩放为 JPEG 文件，
///   保存到 `StorageProviding.pluginDataDirectory("ChatScreenshot")`，
///   再经 `ConversationInputProviding.addToConversation(fileURLs:)` 把图片路径
///   插入输入框（与新版「图片以路径文本插入输入框」策略一致，旧版图片挂起池
///   在新版 `MessageSendingProviding` 中已移除）。
///
/// 与旧版的对应关系：
/// - `chatSectionActionBarItems(.leading)` → `ChatSectionProviding.addBarItems(.actionLeading)`；
/// - `ScreenCaptureService` / `ChatScreenshotState` / 遮罩 Overlay 直接复用旧版实现
///   （仅依赖 AppKit / ScreenCaptureKit，无 KernelLumi 依赖）；
/// - `kernel.messageSender.addAttachment` → 无附件管道，改用
///   `ConversationInputProviding.addToConversation(fileURLs:)` 插入文件路径。
@MainActor
public final class ChatScreenshotPlugin: SuperPlugin {
    /// 保持旧版插件 ID，插件启用状态 / 存储 / 自动化不失效。
    public let id = "com.coffic.lumi.plugin.chat-screenshot"
    public let order = 81

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Chat Screenshot", bundle: .module)
    }

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Chat Screenshot",
            description: "Capture a screenshot region and insert it into the chat composer",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else { return }

        // Action Bar 截图按钮（沿用旧版 chatSectionActionBarItems .leading，order 81）。
        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).button",
                order: 81,
                placement: .actionLeading
            ) {
                ChatScreenshotButtonView(kernel: kernel)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).button")
    }
}
