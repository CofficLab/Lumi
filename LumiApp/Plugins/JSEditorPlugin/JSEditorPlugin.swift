import Foundation
import SwiftUI
import MagicKit

/// JavaScript / TypeScript 编辑器插件
///
/// 提供 JS/TS 项目支持：
/// - package.json 解析与脚本识别
/// - tsconfig 路径映射
/// - Node/Bun 运行时探测
/// - 统一脚本执行桥接
///
/// LSP 能力（补全/跳转/悬停/诊断）复用内核 LSPService，
/// 已内置支持 typescript-language-server。
actor JSEditorPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🟨"

    static let id = "JSEditor"
    static let displayName = String(localized: "JS/TS Editor", table: "JSEditor")
    static let description = String(localized: "JavaScript and TypeScript project support: package.json parsing, tsconfig resolution, and script execution.", table: "JSEditor")
    static let iconName = "js"
    static let order = 33
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { false }
}
