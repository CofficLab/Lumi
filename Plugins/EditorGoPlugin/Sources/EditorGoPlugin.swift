import Foundation
import EditorService
import LumiCoreKit
import ShellKit
import SwiftUI

@MainActor
public enum GoEditorBridge {
    public static var openFileHandler: ((URL, String?) async -> Void)?
}

/// Go 编辑器插件
///
/// 提供 Go 项目支持：
/// - gopls 高级配置（staticcheck、codelenses、analyses）
/// - go.mod 项目检测
/// - go build / go test / go fmt / go mod tidy 命令
/// - 构建输出面板 + 测试结果面板
///
/// LSP 基础能力（补全/跳转/悬停/诊断）复用内核 LSPService，
/// 已内置支持 gopls。
public enum EditorGoPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "goforward"

    public static let info = LumiPluginInfo(
        id: "GoEditor",
        displayName: LumiPluginLocalization.string("Go Editor", bundle: .module),
        description: LumiPluginLocalization.string("Go language support: gopls integration, build, test, format, and module management.", bundle: .module),
        order: 34
    )
}
