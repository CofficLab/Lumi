import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Conversation Input Plugin
///
/// 向 Chat 区域添加输入框和发送按钮。
@MainActor
public final class ConversationInputPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-input")
    public nonisolated static let emoji = "⌨️"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.conversation-input"
    public let name = "Conversation Input"
    public let order = 83
    public static let policy: LumiPluginPolicy = .optOut

    // MARK: - 内部状态

    /// 输入状态（供输入视图和发送按钮共享）
    let inputState = InputState()

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)ConversationInputPlugin")
        }
    }

    // MARK: - LumiPlugin

    public func onReady(kernel: LumiKernel) throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)register ➡️ kernel=\(String(describing: ObjectIdentifier(kernel)))")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)boot 完成")
        }
    }

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        if Self.verbose {
            Self.logger.info("\(Self.t)chatSectionItems ➡️ 注册 1 个 .bottomFixed item (注入 kernel)")
        }
        return [
            ChatSectionItem(
                id: id,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                ConversationInputView(kernel: kernel, inputState: self.inputState)
            }
        ]
    }

    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] {
        [
            ChatSectionActionBarItem(
                id: "\(id).send-button"
            ) {
                SendButtonView(kernel: kernel, inputState: self.inputState)
            }
        ]
    }
}
