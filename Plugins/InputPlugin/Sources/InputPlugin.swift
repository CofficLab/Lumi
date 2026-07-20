import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Input Manager Plugin
@MainActor
public final class InputPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input-manager")
    nonisolated public static let verbose = false

    public let id = "com.coffic.lumi.plugin.input-manager"
    public let name = "Input Manager"
    public let order = 70
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        guard Self.policy.shouldRegister else { return }
        kernel.viewContainer?.register(
            ViewContainerItem(id: id, title: "Input Manager", systemImage: "keyboard") {
                InputSettingsView()
            }
        )
    }

    public func boot(kernel: LumiKernel) async throws {
        if let storage = kernel.storage {
            InputPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
        }
    }
}

enum InputPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.coffic.lumi", isDirectory: true)
    }()
}