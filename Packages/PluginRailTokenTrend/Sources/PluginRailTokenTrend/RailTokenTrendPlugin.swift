import Foundation
import KernelCore
import LumiLoggingKit
import LumiLocalizationKit
import ProviderMessage
import ProviderRailView
import os
import SwiftUI

/// Rail 底部 token 用量趋势插件。
///
/// 在 Rail 侧边栏底部注入最近 30 天 token 消耗折线图，
/// 数据来源于 `MessageManaging`，渲染复用 `AppLineChart`。
@MainActor
public final class RailTokenTrendPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.rail-token-trend", category: "RailTokenTrend")

    public let id = "com.coffic.lumi.plugin.rail-token-trend"
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.rail-token-trend",
        name: "Rail Token Trend",
        description: "Show token usage trend in the Rail bottom.",
        category: .system,
        stage: .experimental,
        policy: .disabledByDefault
    )

    private var viewModel: RailTokenTrendViewModel?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let rail = kernel.resolveProvider((any RailViewProviding).self) else {
            Self.logger.error("\(Self.t)RailViewProviding not found")
            return
        }
        let messages = kernel.resolveProvider((any MessageManaging).self)
        if messages == nil {
            Self.logger.error("\(Self.t)MessageManaging not found")
            return
        }

        let viewModel = RailTokenTrendViewModel(messages: messages)
        self.viewModel = viewModel

        rail.addBottomItems([
            RailBottomItem(id: "\(id).chart", order: 0, height: 120) {
                RailTokenTrendView(viewModel: viewModel)
            }
        ])

        viewModel.loadTrend()
    }
}
