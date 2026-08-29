import KitAgentTool
import KernelCore
import os
import ProviderDocsView
import ProviderToolManager
import KitSuperLog
import SwiftUI

/// OCR 文字识别插件
///
/// 识别逻辑 `OcrEngine` 基于 macOS Vision，纯本地离线，无内核依赖。
@MainActor
public final class OcrPlugin: SuperPlugin, SuperLog {
    public let id = "com.coffic.lumi.plugin.ocr"
    public let order = 286
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.ocr",
        name: "Ocr",
        description: "",
        category: .integration,
        stage: .stable,
        policy: .required
    )

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.ocr")

    public init() {}

    public var name: String { OcrLocalization.string("OCR", "OCR 文字识别") }

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { OcrAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { OcrManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 注册 Agent 工具。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    // MARK: - Agent Tools

    public static let agentTools: [any SuperAgentTool] = [
        OcrImageTool(),
    ]
}
