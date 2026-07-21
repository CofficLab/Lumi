import LumiCoreChat
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Conversation Input Plugin
///
/// 向 Chat 区域底部添加一个输入框（仅 UI 展示，尚未接入发送逻辑）。
@MainActor
public final class ConversationInputPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-input")
    public nonisolated static let emoji = "⌨️"
    nonisolated static let verbose = true

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.conversation-input"
    public let name = "Conversation Input"
    public let order = 83
    public static let policy: LumiPluginPolicy = .optOut

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)ConversationInputPlugin")
        }
    }

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
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
            Self.logger.info("\(Self.t)chatSectionItems ➡️ 注册 1 个 .bottomFixed item")
        }
        return [
            ChatSectionItem(
                id: id,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                ConversationInputView()
            }
        ]
    }
}
