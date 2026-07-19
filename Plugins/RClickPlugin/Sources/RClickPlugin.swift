import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Right Click Plugin
@MainActor
public final class RClickPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rclick")
    nonisolated public static let verbose = false

    public let id = "com.coffic.lumi.plugin.rclick"
    public let name = "Right Click"
    public let order = 50

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.registerViewContainer(
            ViewContainerItem(id: id, title: "Right Click", systemImage: "cursorarrow.click.2") {
                RClickSettingsView()
            }
        )
    }

    public func boot(kernel: LumiKernel) async throws {
        if let storage = kernel.storage {
            RClickPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
        }
    }
}

enum RClickPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.coffic.lumi", isDirectory: true)
    }()
}