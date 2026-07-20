import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// App Manager Plugin
///
/// Browse installed macOS applications.
@MainActor
public final class AppManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-manager")
    nonisolated public static let emoji = "📱"
    nonisolated public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.app-manager"
    public let name = "App Manager"
    public let order = 42
public static let policy: LumiPluginPolicy = .disabled

    /// 数据根目录解析器
    nonisolated(unsafe) public static var databaseRootURLProvider: () -> URL = {
        AppManagerPluginRuntimeBridge.fallbackRootDirectory
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        guard Self.policy.shouldRegister else { return }
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: "App Manager",
                systemImage: "apps.ipad"
            ) {
                AppManagerView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 App Manager 视图容器到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // 设置数据目录
        if let storage = kernel.storage {
            AppManagerPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
            Self.databaseRootURLProvider = { storage.dataRootDirectory }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)App Manager 插件启动完成")
        }
    }
}

// MARK: - Runtime Bridge

enum AppManagerPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}