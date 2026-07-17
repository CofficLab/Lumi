import Foundation
import LumiCoreKit

/// RClickPlugin 的运行时桥接:持有 LumiCore 数据根目录,
/// 供 `RClickPluginLocalStore` 读取(替代旧的 nonisolated 镜像变量)。
enum RClickPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}

@MainActor
public extension RClickPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            RClickPluginRuntimeBridge.dataRootDirectory = core.dataRootDirectory
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
