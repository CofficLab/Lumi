import Foundation
import EditorService
import XcodeKit
import os
import SuperLogKit

@MainActor
public final class XcodePlistHoverContributor: SuperEditorHoverContributor, SuperLog {
    public let id = "builtin.xcode.plist-hover"

    public func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t)💬 XcodePlistHoverContributor | 开始处理 hover，symbol: \(context.symbol)")
            }
        }
        
        let runtimeContext = SuperEditorRuntimeContext.shared
        guard let fileURL = runtimeContext.currentFileURL else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.warning("\(Self.t)⚠️ XcodePlistHoverContributor | 无法获取当前文件 URL")
                }
            }
            return []
        }

        let symbol = context.symbol

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t)💬 XcodePlistHoverContributor | 文件: \(fileURL.path), symbol: \(symbol)")
            }
        }

        // Markdown 生成移到后台线程（可能涉及文件读取和解析）
        let markdown: String? = await Task.detached(priority: .userInitiated) {
            let result = PlistEditing.hoverMarkdown(for: symbol, fileURL: fileURL)
            if SwiftPluginLog.verbose {
                if result != nil {
                    if SwiftPluginLog.verbose {
                                            SwiftPluginLog.logger.info("\(Self.t)💬 XcodePlistHoverContributor [后台] | 生成 markdown 成功")
                    }
                } else {
                    if SwiftPluginLog.verbose {
                                            SwiftPluginLog.logger.info("\(Self.t)💬 XcodePlistHoverContributor [后台] | 无 hover 结果")
                    }
                }
            }
            return result
        }.value

        guard let markdown else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.info("\(Self.t)💬 XcodePlistHoverContributor | hover 结果为空，返回空数组")
                }
            }
            return []
        }

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t)✅ XcodePlistHoverContributor | Hover 生成完成，symbol: \(symbol)")
            }
        }

        return [.init(markdown: markdown, priority: 180, dedupeKey: "plist:\(symbol.lowercased())")]
    }
}
