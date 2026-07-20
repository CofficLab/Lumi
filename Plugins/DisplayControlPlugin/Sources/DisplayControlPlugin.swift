import Foundation
import LumiKernel
import LumiUI
import SwiftUI
import os

/// Display Control Plugin
///
/// Control brightness, volume, and contrast for external displays via DDC/CI.
@MainActor
public final class DisplayControlPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.display-control")

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.display-control"
    public let name = "Display Control"
    public let order = 21
public static let policy: LumiPluginPolicy = .disabled

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: "Display Control",
                systemImage: "display"
            ) {
                DisplayControlView()
            }
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}