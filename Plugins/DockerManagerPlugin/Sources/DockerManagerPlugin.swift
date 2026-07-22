import Foundation
import LumiKernel
import LumiUI
import ShellKit
import SuperLogKit
import SwiftUI
import os

/// Docker Manager Plugin
@MainActor
public final class DockerManagerPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.docker-manager")
    nonisolated public static let verbose = false

    public let id = "com.coffic.lumi.plugin.docker-manager"
    public let name = "Docker"
    public let order = 50
public static let policy: LumiPluginPolicy = .disabled

    public var policy: LumiPluginPolicy { .disabled }

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        guard Self.policy.shouldRegister else { return }
        kernel.viewContainer?.register(
            ViewContainerItem(id: id, title: "Docker", systemImage: "shippingbox") {
                DockerImagesView()
            }
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}

enum PluginDockerManagerLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module
    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}