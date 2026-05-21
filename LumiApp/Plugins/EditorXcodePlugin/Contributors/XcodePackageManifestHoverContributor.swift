import Foundation
import XcodeKit
import os

@MainActor
final class XcodePackageManifestHoverContributor: SuperEditorHoverContributor, SuperLog {
    let id = "builtin.xcode.package-manifest-hover"

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t)开始处理 hover，line: \(context.line), character: \(context.character)")
            }
        }

        let runtimeContext = SuperEditorRuntimeContext.shared
        guard let fileURL = runtimeContext.currentFileURL else {
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.warning("\(Self.t)无法获取当前文件 URL")
                }
            }
            return []
        }

        guard fileURL.lastPathComponent == "Package.swift" else {
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.info("\(Self.t)当前文件不是 Package.swift，跳过: \(fileURL.lastPathComponent)")
                }
            }
            return []
        }

        let line = context.line
        let character = context.character
        let content = runtimeContext.currentContent

        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t)文件: \(fileURL.path), 内容长度: \(content.count ?? 0)")
            }
        }

        // Markdown 生成移到后台线程（涉及语法解析）
        let markdown: String? = await Task.detached(priority: .userInitiated) {
            let startTime = CFAbsoluteTimeGetCurrent()
            let result = PackageManifestSyntax.hoverMarkdown(
                line: line,
                character: character,
                in: content
            )
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            if XcodePluginLog.verbose {
                if result != nil {
                    if XcodePluginLog.verbose {
                                            XcodePluginLog.logger.info("\(Self.t)生成 markdown 成功，耗时 \(String(format: "%.1f", elapsed))ms")
                    }
                } else {
                    if XcodePluginLog.verbose {
                                            XcodePluginLog.logger.info("\(Self.t)无 hover 结果，耗时 \(String(format: "%.1f", elapsed))ms")
                    }
                }
            }
            return result
        }.value

        guard let markdown else {
            if XcodePluginLog.verbose {
                if XcodePluginLog.verbose {
                                    XcodePluginLog.logger.info("\(Self.t)hover 结果为空，返回空数组")
                }
            }
            return []
        }

        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(Self.t)Hover 生成完成，line: \(line), character: \(character)")
            }
        }

        return [
            .init(
                markdown: markdown,
                priority: 170,
                dedupeKey: "package-manifest:\(line):\(character)"
            )
        ]
    }
}
