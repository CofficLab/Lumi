import Foundation
import LumiKernel
import SwiftUI
import SuperLogKit
import os

// MARK: - Default Logo Provider

/// 默认 Logo 服务实现
///
/// 负责管理所有插件的 Logo 项的注册和查询。
@MainActor
public final class LogoManager: LogoProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.logo")
    public nonisolated static let emoji = "🖼️"
    nonisolated static let verbose = true
    public private(set) var allLogoItems: [LogoItem] = []

    private var logoItems: [String: LogoItem] = [:]
    private var logoItemOrder: [String] = []

    public init() {}

    public func registerLogoItem(_ item: LogoItem) {
        if Self.verbose {
            Self.logger.info("\(Self.t)注册Logo：\(item.id)")
        }
        if logoItems[item.id] == nil {
            logoItemOrder.append(item.id)
        }
        logoItems[item.id] = item
        updateSortedItems()
    }

    public func unregisterLogoItem(id: String) {
        logoItems.removeValue(forKey: id)
        logoItemOrder.removeAll { $0 == id }
        updateSortedItems()
    }

    public func clearAllContributions() {
        logoItems.removeAll()
        logoItemOrder.removeAll()
        updateSortedItems()
    }

    private func updateSortedItems() {
        allLogoItems = logoItemOrder.compactMap { logoItems[$0] }
            .sorted { $0.order > $1.order }
    }
}
