import Foundation
import LumiKernel

/// OnboardingPlugin 的运行时桥接:持有 Storage service 解析出的插件目录,
/// 供 `OnboardingPluginStore` 读取。
enum OnboardingPluginRuntimeBridge {
    nonisolated(unsafe) static var pluginDirectory: URL?

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()

    static let pluginName = "Onboarding"
}

@MainActor
public extension OnboardingPlugin {
    static func bootstrapFromLumiCoreIfNeeded(kernel: LumiKernel) {
        guard !didBootstrapFromLumiCore else { return }
        if let storage = kernel.storage {
            OnboardingPluginRuntimeBridge.pluginDirectory =
                storage.pluginDataDirectory(for: OnboardingPluginRuntimeBridge.pluginName)
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
