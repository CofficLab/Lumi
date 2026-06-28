import Foundation
import EditorService
import XcodeKit
import os
import SuperLogKit
import LumiCoreKit

// MARK: - Quick Open Contributor

@MainActor
public final class XcodeProjectQuickOpenContributor: SuperEditorQuickOpenContributor, SuperLog {
    public let id = "builtin.xcode.quick-open"

    public func provideQuickOpenItems(
        query: String,
        state: EditorState
    ) async -> [EditorQuickOpenItemSuggestion] {
        guard let projectRootPath = state.projectRootPath, !projectRootPath.isEmpty else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.warning("\(Self.t)⚠️ XcodeProjectQuickOpenContributor | projectRootPath 为空，跳过")
                }
            }
            return []
        }
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.info("\(Self.t)📂 XcodeProjectQuickOpenContributor | 查询为空，跳过")
                }
            }
            return []
        }

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t)📂 XcodeProjectQuickOpenContributor | 开始收集建议，projectRoot: \(projectRootPath), 查询: \(normalizedQuery)")
            }
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // 将文件 I/O 和解析移到后台线程
        let rawResults: [RawQuickOpenMatch] = await Task.detached(priority: .userInitiated) {
            let backgroundStartTime = CFAbsoluteTimeGetCurrent()
            let results = Self.collectRawMatches(query: normalizedQuery, projectRootPath: projectRootPath)
            let elapsed = (CFAbsoluteTimeGetCurrent() - backgroundStartTime) * 1000
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.info("\(Self.t)📂 XcodeProjectQuickOpenContributor [后台] | 原始匹配收集完成，\(results.count) 条，耗时 \(String(format: "%.1f", elapsed))ms")
                }
            }
            return results
        }.value

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t)📂 XcodeProjectQuickOpenContributor | 开始构造 UI 建议，rawResults: \(rawResults.count)")
            }
        }

        // 回到主线程构造 UI 建议（action 闭包需要访问 MainActor 的 state）
        let suggestions = rawResults.enumerated().map { index, match in
            let target = CursorPosition(start: .init(line: match.line, column: 1), end: nil)
            return EditorQuickOpenItemSuggestion(
                id: "xcode-key:\(match.filePath):\(match.line):\(match.key)",
                sectionTitle: LumiPluginLocalization.string("Project Keys", bundle: .module),
                title: match.key,
                subtitle: "\(match.relativePath):\(match.line)",
                systemImage: match.isXCConfig ? "slider.horizontal.3" : "list.bullet.rectangle",
                badge: match.isXCConfig ? "xcconfig" : match.fileExtension,
                order: index,
                isEnabled: true,
                metadata: .init(
                    priority: match.isXCConfig ? 180 : 170,
                    dedupeKey: "\(match.filePath):\(match.key):\(match.line)"
                ),
                action: {
                    state.performNavigation(.definition(URL(filePath: match.filePath), target, highlightLine: true))
                }
            )
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t)📂 XcodeProjectQuickOpenContributor | 完成，\(suggestions.count) 条结果，耗时 \(String(format: "%.1f", elapsed))ms")
            }
        }

        return suggestions
    }

    // MARK: - Background Data Collection

    /// 后台线程执行：遍历目录、读取文件、匹配键
    nonisolated static func collectRawMatches(
        query normalizedQuery: String,
        projectRootPath: String
    ) -> [RawQuickOpenMatch] {
        let projectRootURL = URL(fileURLWithPath: projectRootPath)
        guard let enumerator = FileManager.default.enumerator(
            at: projectRootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [RawQuickOpenMatch] = []

        for case let fileURL as URL in enumerator {
            guard results.count < 24 else { break }
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "xcconfig" || ext == "plist" || ext == "entitlements" else { continue }
            var encoding = String.Encoding.utf8
            guard let content = try? String(contentsOf: fileURL, usedEncoding: &encoding) else { continue }

            let matches: [(key: String, line: Int)] = if ext == "xcconfig" {
                XCConfigSyntax.keyOccurrences(in: content)
                    .filter { $0.key.lowercased().contains(normalizedQuery) }
                    .map { ($0.key, $0.line) }
            } else {
                PlistEditing.keyOccurrences(in: content)
                    .filter { $0.key.lowercased().contains(normalizedQuery) }
                    .map { ($0.key, $0.line) }
            }

            let isXCConfig = ext == "xcconfig"
            let relativePath = fileURL.path.hasPrefix(projectRootPath + "/")
                ? String(fileURL.path.dropFirst(projectRootPath.count + 1))
                : fileURL.lastPathComponent

            for match in matches.prefix(max(0, 24 - results.count)) {
                results.append(RawQuickOpenMatch(
                    key: match.key,
                    line: match.line,
                    filePath: fileURL.path,
                    relativePath: relativePath,
                    fileExtension: ext,
                    isXCConfig: isXCConfig
                ))
            }
        }

        return results
    }
}

// MARK: - Raw Match Model

/// 后台线程收集的匹配结果（Sendable，用于跨线程传递）
struct RawQuickOpenMatch: Equatable, Sendable {
    let key: String
    let line: Int
    let filePath: String
    let relativePath: String
    let fileExtension: String
    let isXCConfig: Bool
}
