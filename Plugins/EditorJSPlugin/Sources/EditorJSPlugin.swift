import Foundation
import EditorService
import LumiCoreKit
import ShellKit
import SwiftUI

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
public enum EditorJSPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "js"

    public static let info = LumiPluginInfo(
        id: "JSEditor",
        displayName: LumiPluginLocalization.string("JS/TS Editor", bundle: .module),
        description: LumiPluginLocalization.string("JavaScript and TypeScript project support: package.json parsing, tsconfig resolution, and script execution.", bundle: .module),
        order: 33
    )
}
