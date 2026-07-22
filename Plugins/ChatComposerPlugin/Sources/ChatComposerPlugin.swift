import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

/// Chat 输入框插件
///
/// 通过 ChatSection 注入方式向 Chat 区域底部添加输入框。
@MainActor
public final class ChatComposerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-composer"
    public let name = "Chat Composer"
    public let order = 96
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onReady(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        guard let coordinator = kernel.resolveService(ChatSectionCoordinator.self) else {
            return []
        }

        return [
            ChatSectionItem(
                id: id,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                ComposerSectionView(coordinator: coordinator)
            }
        ]
    }
}
