import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Video Converter Plugin
///
/// Provides a view container for video format conversion using FFmpeg.
@MainActor
public final class VideoConverterPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.video-converter")
    nonisolated public static let emoji = "🎬"
    nonisolated public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.video-converter"
    public let name = "Video Converter Plugin"
    public let order = 70
public static let policy: LumiPluginPolicy = .disabled

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        guard Self.policy.shouldRegister else { return }
        // 注册视图容器（order 自动从插件继承）
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: VideoConverterLocalization.string("Video Converter"),
                systemImage: "video"
            ) {
                VideoConverterMainView()
            }
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Video Converter 视图容器到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Video Converter 插件启动完成")
        }
    }
}