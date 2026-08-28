import Foundation
import KernelCore
import ProviderConversationInput
import ProviderStorage

/// 简历设计器的运行时状态（KernelCore 体系）。
///
/// 由旧版 `Plugins/ResumeDesignerPlugin/Sources/Services/Runtime.swift` 迁移而来。
/// 与旧版一致：简历文档只存储在应用数据目录（app 作用域），不支持项目内（.lumi）
/// 存储，因此无需像 Icon/Promo 插件那样安装项目路径观察者。
@MainActor
enum ResumeDesignerRuntime {
    /// APP 内存储目录（应用级别，跨项目共享）。
    static private(set) var appStorageDirectory: URL?

    /// 聊天输入框服务（宿主注入，可空）。用于把选中的区块预填进输入框待发送。
    static var conversationInput: (any ConversationInputProviding)?

    static func configure(kernel: KernelCoreContainer, pluginID: String) {
        conversationInput = kernel.resolveProvider((any ConversationInputProviding).self)
        let appDirectory = kernel.resolveProvider((any StorageProviding).self)?
            .pluginDataDirectory(for: pluginID)
        configure(appStorageDirectory: appDirectory)
    }

    static func configure(appStorageDirectory: URL?) {
        let resolved = appStorageDirectory?.standardizedFileURL
        guard self.appStorageDirectory != resolved else { return }
        self.appStorageDirectory = resolved
        WorkspaceStore.shared.setAppStorage(appStorageDirectory: resolved)
    }

    /// 测试辅助：重置所有运行时状态。
    static func reset() {
        appStorageDirectory = nil
        conversationInput = nil
        WorkspaceStore.shared.setAppStorage(appStorageDirectory: nil)
    }
}
