import Foundation
import LumiLoggingKit
import ProviderLLMManager
import os

/// 「当前是否选中 MiniMax」的可观察门控。
///
/// 工具栏 chip 需要在供应商切换时立即出现 / 消失，而能力层的回调
/// 本身不是 SwiftUI 的数据源，因此用本类型在事件与视图之间传递选中态。
@MainActor
final class MiniMaxSelectionGate: ObservableObject {
    /// MiniMax 三个协议变体共享同一批模型与 API Key，任一选中即展示配额。
    nonisolated static let providerIDs: Set<String> = [
        "minimax-tokenplan",
        "minimax-tokenplan-anthropic",
        "minimax-responses",
    ]

    @Published private(set) var isEnabled: Bool

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    /// 由 `providerID` 直接驱动；未选中任何供应商时按 false 处理。
    func update(providerID: String?) {
        isEnabled = providerID.map { Self.providerIDs.contains($0) } ?? false
    }
}

/// 把「生效供应商」同步到 ``MiniMaxSelectionGate`` 的观察者。
///
/// ## 判定口径
///
/// 观察的是**当前对话实际生效的供应商**（对话钉选优先、回落到全局选中），
/// 而不是全局选中项。模型可以钉在单个对话上，两者在多供应商并存的场景下
/// 会指向不同供应商——只看全局选中项会让配额 chip 与实际请求去向脱节。
///
/// **生命周期**：本类型不提供 `deinit` 取消——观察句柄非 `Sendable`，
/// `deinit` 是 nonisolated 上下文，触碰它会触发并发检查。取消义务因此交给
/// 持有者：插件在 `onShutdown` 显式调用 ``cancel()``。
@MainActor
final class MiniMaxSelectionObserver: SuperLog {
    nonisolated private static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.llm-provider.minimax",
        category: "MiniMaxSelection"
    )
    nonisolated static let emoji = "🎯"
    nonisolated static let verbose = false

    private let capability: any MiniMaxQuotaCapability
    private let gate: MiniMaxSelectionGate
    private let onSelect: () -> Void
    private let onDeselect: () -> Void

    private var handle: (any MiniMaxQuotaObserverHandle)?

    init(
        capability: any MiniMaxQuotaCapability,
        gate: MiniMaxSelectionGate,
        onSelect: @escaping () -> Void,
        onDeselect: @escaping () -> Void
    ) {
        self.capability = capability
        self.gate = gate
        self.onSelect = onSelect
        self.onDeselect = onDeselect
    }

    // MARK: - Event Handler

    /// 开始观察并立即同步一次当前状态（插件 onBoot 晚于用户上次选择，必须补同步）。
    func start() {
        handle?.cancel()
        handle = capability.addObserver { [weak self] providerID in
            self?.sync(providerID: providerID)
        }
        sync(providerID: capability.effectiveProviderID)
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }

    // MARK: - Private

    private func sync(providerID: String?) {
        gate.update(providerID: providerID)

        if Self.verbose {
            Self.logger.debug("\(Self.t)effectiveProviderID=\(providerID ?? "nil", privacy: .public) showChip=\(self.gate.isEnabled, privacy: .public)")
        }

        if gate.isEnabled {
            onSelect()
        } else {
            onDeselect()
        }
    }
}
