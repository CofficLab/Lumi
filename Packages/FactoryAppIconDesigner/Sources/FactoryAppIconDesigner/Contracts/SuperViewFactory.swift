import KernelCore
import SwiftUI

/// 产出 AppIconDesigner 主窗口与设置窗口视图的工厂契约。
@MainActor
public protocol ViewFactory {
    func makeMainView(kernel: KernelCoreContainer) throws -> AnyView
    func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView
}
