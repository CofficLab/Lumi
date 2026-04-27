import Foundation
import SwiftUI
import os
import MagicKit
import Combine

/// 面包屑导航插件：在工具栏显示当前文件路径的导航条
///
/// 作为 Lumi App 的独立插件，提供文件路径的面包屑导航功能。
/// 当用户选择文件时，在工具栏前导位置显示可点击的路径段，
/// 支持点击弹出同级文件/文件夹列表快速导航。
actor BreadcrumbPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.breadcrumb")

    nonisolated static let emoji = "🧭"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "Breadcrumb"
    static let displayName: String = String(localized: "Breadcrumb Navigation", table: "Breadcrumb")
    static let description: String = String(localized: "File path breadcrumb navigation in toolbar", table: "Breadcrumb")
    static let iconName: String = "folder"
    static var isConfigurable: Bool { false }
    static var order: Int { 75 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = BreadcrumbPlugin()

    // MARK: - UI Contributions

    /// 在工具栏前导位置显示面包屑导航
    @MainActor func addToolBarLeadingView() -> AnyView? {
        AnyView(BreadcrumbToolBarView())
    }
}
