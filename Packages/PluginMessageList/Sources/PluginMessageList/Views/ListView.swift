import Foundation
import KitSuperLog
import LumiUI
import os
import ProviderConversation
import SwiftUI

/// Message List View (入口)
///
/// 根据当前会话的 verbosity 分发到对应的消息列表子视图。
/// 所有路由状态与子 ViewModel 均由 `MessageListPlugin` 创建并注入。
struct ListView: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-list", category: "ListView")
    nonisolated public static let emoji = "📋"
    nonisolated static let verbose = false

    let services: MessageListServices
    let viewModels: MessageListViewModels
    @ObservedObject private var viewModel: MessageListRootViewModel

    @LumiTheme private var theme

    init(services: MessageListServices, viewModels: MessageListViewModels) {
        self.services = services
        self.viewModels = viewModels
        _viewModel = ObservedObject(wrappedValue: viewModels.root)
        if Self.verbose {
            Self.logger.info("\(Self.t)ListView initialized: selectedConversation=\(viewModels.root.selectedConversationID?.uuidString ?? "nil"), verbosity=\(viewModels.root.verbosity.rawValue)")
        }
    }

    var body: some View {
        Group {
            if viewModel.selectedConversationID == nil {
                NoConversationSelectedView(
                    services: services,
                    guideState: viewModels.guide
                )
            } else {
                LiveResizeFrozenView {
                    routedMessageList
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var routedMessageList: some View {
        if Self.verbose {
            let _ = Self.logger.info("\(Self.t)route list: selected=\(viewModel.selectedConversationID?.uuidString ?? "nil"), verbosity=\(viewModel.verbosity.rawValue) → \(verbosityRouteName)")
        }
        switch viewModel.verbosity {
        case .brief:
            ListV1View(
                services: services,
                viewModel: viewModels.v1,
                rootViewModel: viewModels.root,
                guideState: viewModels.guide
            )
        case .standard:
            ListV2View(services: services, viewModel: viewModels.v2, guideState: viewModels.guide)
        case .detailed:
            ListV3View(services: services, viewModel: viewModels.v3, guideState: viewModels.guide)
        }
    }

    private var verbosityRouteName: String {
        switch viewModel.verbosity {
        case .brief: "V1 (brief)"
        case .standard: "V2 (standard)"
        case .detailed: "V3 (detailed)"
        }
    }
}
