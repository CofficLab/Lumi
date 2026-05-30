import Foundation
import EditorService
import XcodeKit
import os

@MainActor
public final class XcodePlistHoverContributor: SuperEditorHoverContributor {
    public let id = "builtin.xcode.plist-hover"

    public func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("💬 XcodePlistHoverContributor | 开始处理 hover，symbol: \(context.symbol)")
            }
        }
        
        let runtimeContext = SuperEditorRuntimeContext.shared
        guard let fileURL = runtimeContext.currentFileURL else {
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.warning("⚠️ XcodePlistHoverContributor | 无法获取当前文件 URL")
                }
            }
            return []
        }

        let symbol = context.symbol

        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("💬 XcodePlistHoverContributor | 文件: \(fileURL.path), symbol: \(symbol)")
            }
        }

        // Markdown 生成移到后台线程（可能涉及文件读取和解析）
        let markdown: String? = await Task.detached(priority: .userInitiated) {
            let result = PlistEditing.hoverMarkdown(for: symbol, fileURL: fileURL)
            if XcodePluginLog.verbose {
                if result != nil {
                    if XcodePluginLog.verbose {
                                            XcodePluginLog.logger.info("💬 XcodePlistHoverContributor [后台] | 生成 markdown 成功")
                    }
                } else {
                    if XcodePluginLog.verbose {
                                            XcodePluginLog.logger.info("💬 XcodePlistHoverContributor [后台] | 无 hover 结果")
                    }
                }
            }
            return result
        }.value

        guard let markdown else {
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.info("💬 XcodePlistHoverContributor | hover 结果为空，返回空数组")
                }
            }
            return []
        }

        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("✅ XcodePlistHoverContributor | Hover 生成完成，symbol: \(symbol)")
            }
        }

        return [.init(markdown: markdown, priority: 180, dedupeKey: "plist:\(symbol.lowercased())")]
    }
}
