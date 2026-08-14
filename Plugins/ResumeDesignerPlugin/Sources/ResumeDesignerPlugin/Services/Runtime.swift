import Combine
import Foundation
import KernelLumi

@MainActor
enum Runtime {
    /// APP 内存储目录（应用级别，跨项目共享）。
    /// 简历文档只存储在应用数据目录，不支持项目内（.lumi）存储。
    static private(set) var appStorageDirectory: URL?

    /// 内核实例（在 `onBoot` 时注入），供视图层访问 `conversationInput` 等服务。
    static private(set) var kernel: KernelLumi?

    static func configure(kernel: KernelLumi) {
        Runtime.kernel = kernel
        configure(appStorageDirectory: kernel.storage?.pluginDataDirectory(for: "ResumeDesigner"))
    }

    static func configure(appStorageDirectory: URL?) {
        let resolved = appStorageDirectory?.standardizedFileURL
        guard Runtime.appStorageDirectory != resolved else { return }
        Runtime.appStorageDirectory = resolved
        WorkspaceStore.shared.setAppStorage(appStorageDirectory: resolved)
    }

    /// 测试辅助：重置所有运行时状态。
    static func reset() {
        appStorageDirectory = nil
        kernel = nil
        WorkspaceStore.shared.setAppStorage(appStorageDirectory: nil)
    }
}
