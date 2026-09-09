import Foundation
import os
import ProviderLogo
import KitSuperLog
import SwiftUI

/// `LogoProviding` 的自研实现：持有 Logo 项字典与顺序，按 `order` 降序对外暴露。
///
/// 复刻旧版 `LogoManager`（KernelLumi 体系），迁移至 KernelCore 生态：
/// - 插件通过 `registerLogoItem(_:)` 追加自己的 Logo 贡献（同 id 覆盖）；
/// - 消费方通过 `addLogoObserver` 感知 Logo 集合与高亮状态变化；
/// - 内置结构化日志，便于诊断注册 / 注销 / 高亮状态切换。
@MainActor
public final class LogoManager: LogoProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.logo-manager", category: "Plugin")
    public nonisolated static let emoji = "🖼️"
    nonisolated static let verbose = false

    public private(set) var isLogoHighlighted = false
    public private(set) var allLogoItems: [LogoItem] = []

    private var logoItems: [String: LogoItem] = [:]
    private var logoItemOrder: [String] = []
    private var observers: [UUID: (LogoProvidingEvent) -> Void] = [:]

    public init() {}

    public func setLogoHighlighted(_ highlighted: Bool) {
        guard isLogoHighlighted != highlighted else {
            return
        }
        Self.logger.info("[LogoHighlight] \(self.isLogoHighlighted) -> \(highlighted)")
        isLogoHighlighted = highlighted
        notify(.highlightChanged(highlighted))
    }

    @discardableResult
    public func addLogoObserver(
        _ callback: @escaping (LogoProvidingEvent) -> Void
    ) -> any LogoObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public func registerLogoItem(_ item: LogoItem) {
        if Self.verbose {
            Self.logger.info("\(Self.t)注册 Logo：\(item.id, privacy: .public)（order=\(item.order)）")
        }
        if logoItems[item.id] == nil {
            logoItemOrder.append(item.id)
        }
        logoItems[item.id] = item
        updateSortedItems()
        notify(.itemsChanged)
    }

    public func unregisterLogoItem(id: String) {
        if Self.verbose {
            Self.logger.info("\(Self.t)注销 Logo：\(id, privacy: .public)")
        }
        logoItems.removeValue(forKey: id)
        logoItemOrder.removeAll { $0 == id }
        updateSortedItems()
        notify(.itemsChanged)
    }

    public func clearAllContributions() {
        if Self.verbose {
            Self.logger.info("\(Self.t)清空全部 Logo 贡献（\(self.logoItems.count) 项）")
        }
        logoItems.removeAll()
        logoItemOrder.removeAll()
        updateSortedItems()
        notify(.itemsChanged)
    }

    private func updateSortedItems() {
        allLogoItems = logoItemOrder.compactMap { logoItems[$0] }
            .sorted { $0.order > $1.order }
    }

    private func notify(_ event: LogoProvidingEvent) {
        observers.values.forEach { $0(event) }
    }

    private final class ObserverHandle: LogoObserverHandle {
        private var cancellation: (() -> Void)?

        init(cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        func cancel() {
            cancellation?()
            cancellation = nil
        }
    }
}
