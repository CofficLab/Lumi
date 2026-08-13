import Foundation
import KernelLumi
import SwiftUI

/// OnboardingPlugin 的运行时桥接:持有 Storage service 解析出的插件目录,
/// 供 `PluginStore` 读取。
enum RuntimeBridge {
    nonisolated(unsafe) static var pluginDirectory: URL?
    nonisolated(unsafe) static var viewModel: PluginViewModel?

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
    static func bootstrapFromLumiCoreIfNeeded(kernel: KernelLumi) {
        guard !didBootstrapFromLumiCore else { return }
        if let storage = kernel.storage {
            RuntimeBridge.pluginDirectory =
                storage.pluginDataDirectory(for: RuntimeBridge.pluginName)
        }
        didBootstrapFromLumiCore = true
    }

    static func initializeViewModel(kernel: KernelLumi) {
        guard RuntimeBridge.viewModel == nil else { return }
        let store: PluginStore
        if let storage = kernel.storage {
            let pluginDirectory = storage.pluginDataDirectory(for: RuntimeBridge.pluginName)
            let settingsDirectory = pluginDirectory.appendingPathComponent("settings", isDirectory: true)
            store = PluginStore(settingsDirectory: settingsDirectory)
        } else {
            store = PluginStore(pluginId: RuntimeBridge.pluginName)
        }
        RuntimeBridge.viewModel = PluginViewModel(store: store)
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
