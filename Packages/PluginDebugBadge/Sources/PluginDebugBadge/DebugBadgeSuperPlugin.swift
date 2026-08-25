import Foundation
import KernelCore
import LumiUI
import os
import ProviderToolbar
import KitSuperLog
import SwiftUI

// MARK: - Debug Badge SuperPlugin

/// Debug Badge 插件
///
/// 在 Debug 构建下，于标题工具栏左上角显示一个橙色「DEBUG」胶囊徽标，
/// 提示用户当前运行的是 Debug 构建（行为类似 Flutter 的 debug 标识）。
///
/// 徽标视图本身由 `#if DEBUG` 编译剔除，Release 构建中插件不贡献任何工具栏项；
/// 同时 `enabledByDefault` 在 Release 下为 `false`，确保零足迹。
@MainActor
public final class DebugBadgeSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.debug-badge", category: "DebugBadge")

    public let id = "com.coffic.lumi.plugin.debug-badge"
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.debug-badge",
        name: "Debug Badge Super",
        description: "",
        category: .general,
        stage: .stable,
        policy: .required
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        #if DEBUG
            guard let toolbar = kernel.resolveProvider(ToolbarProviding.self) else {
                Self.logger.error("\(Self.t)Failed to resolve ToolbarProviding from kernel")
                return
            }
            toolbar.addToolbarItems([
                ToolbarItem(
                    id: "\(id).badge",
                    title: "Running a Debug build",
                    placement: .leading,
                    order: 900
                ) {
                    DebugBadgeView()
                },
            ])
        #endif
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        #if DEBUG
            guard let toolbar = kernel.resolveProvider(ToolbarProviding.self) else {
                Self.logger.error("\(Self.t)Failed to resolve ToolbarProviding from kernel")
                return
            }
            toolbar.removeToolbarItems(ids: ["\(id).badge"])
        #endif
    }
}

// MARK: - Debug Badge View

/// 标题工具栏左上角的「DEBUG」胶囊徽标。
///
/// 使用主题 `warning` 色（橙 #FF9F0A）作为背景，白色粗体文字，
/// 与 Lumi 主题体系保持一致。
#if DEBUG
    private struct DebugBadgeView: View {
        @LumiTheme private var theme: any LumiUITheme

        var body: some View {
            Text("DEBUG")
                .font(.appMicroEmphasized)
                .tracking(0.3)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.warning, in: Capsule())
        }
    }
#endif
