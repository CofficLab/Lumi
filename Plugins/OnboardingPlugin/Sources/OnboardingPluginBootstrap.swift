import Foundation
import LumiKernel

/// OnboardingPlugin 的运行时桥接:持有 LumiCore 数据根目录,
/// 供 `OnboardingPluginStore` 读取(替代旧的 nonisolated 镜像变量)。
enum OnboardingPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}

@MainActor
public extension OnboardingPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: any LumiCoreAccessing) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            OnboardingPluginRuntimeBridge.dataRootDirectory = core.storage.dataRootDirectory
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
