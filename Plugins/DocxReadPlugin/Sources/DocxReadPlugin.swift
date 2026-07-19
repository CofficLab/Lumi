import Foundation
import LumiCoreKit
import os
import SwiftUI

/// DocxRead 插件
///
/// 提供读取 DOCX 文件正文内容的工具，供 Agent 在对话中调用。
public enum DocxReadPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.docx-read",
        displayName: LumiPluginLocalization.string("Docx Read", bundle: .module),
        description: LumiPluginLocalization.string("Read DOCX file content for Agent.", bundle: .module),
        order: 90,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "doc.text",
    )

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.docx-read")

    @MainActor
    public static func agentTools(context: any LumiCoreAccessing) -> [any LumiAgentTool] {
        [
            DocxReadTool()
        ]
    }
}
