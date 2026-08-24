import FactoryLumi2
import KernelCore
import SwiftUI

/// V2 composition root for the BookletMaker specialist app.
@MainActor
public enum FactoryBookletMaker2 {
    private static let pluginIDs: Set<String> = [
        "com.coffic.lumi.plugin.storage",
        "com.coffic.lumi.plugin.command",
        "com.coffic.lumi.plugin.projects",
        "com.coffic.lumi.plugin.editor-host",
        "com.coffic.lumi.plugin.setting-general",
        "com.coffic.lumi.plugin.setting-view",
        "com.coffic.lumi.plugin.llm-manager",
        "com.coffic.lumi.plugin.agent-loop",
        "com.coffic.lumi.plugin.message-sender",
        "CoreMessageRenderer",
        "com.coffic.lumi.plugin.booklet-maker"
    ]

    public static func makeKernel() throws -> KernelCoreContainer {
        try KernelFactory.makeKernel(
            pluginFactory: SelectedPluginFactory(allowedPluginIDs: pluginIDs)
        )
    }

    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeMainView(kernel: kernel)
    }

    public static func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeSettingsView(kernel: kernel)
    }
}
