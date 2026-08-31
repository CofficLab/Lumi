import KernelCore
import SwiftUI

/// AppIconDesigner 专用的 KernelCore 宿主组合。
///
/// Provider、Plugin 和 View 的装配均由本包负责；独立 App 不再依赖完整的
/// FactoryLumi，只启动图标设计器所需的能力。
@MainActor
public enum FactoryAppIconDesigner {
    public static let appIconDesignerPluginID = "com.coffic.lumi.plugin.app-icon-designer"

    public static func makeKernel() throws -> KernelCoreContainer {
        try KernelFactory.makeKernel()
    }

    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeMainView(kernel: kernel)
    }

    public static func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeSettingsView(kernel: kernel)
    }
}
