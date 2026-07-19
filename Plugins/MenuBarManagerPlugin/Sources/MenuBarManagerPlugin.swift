import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Menu Bar Manager Plugin
@MainActor
public final class MenuBarManagerPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar-manager")
    nonisolated public static let verbose = false

    public let id = "com.coffic.lumi.plugin.menubar-manager"
    public let name = "Menu Bar Manager"
    public let order = 20

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.registerViewContainer(
            ViewContainerItem(id: id, title: "Menu Bar Manager", systemImage: "menubar.rectangle") {
                MenuBarSettingsView()
            }
        )
    }

    public func boot(kernel: LumiKernel) async throws {
        if let storage = kernel.storage {
            MenuBarManagerPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
        }
    }
}

enum MenuBarManagerPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.coffic.lumi", isDirectory: true)
    }()
}