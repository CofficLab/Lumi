import Foundation
import LumiPreviewKit

public extension LumiHotPreviewPackage {
    struct ProjectPreviewPrewarmRanker: Sendable {
        public struct Context: Sendable {
            public let activeFileURL: URL?
            public let recentFilePaths: [String]
            public let successfulFilePaths: [String]
            public let previewStartCountsByFilePath: [String: Int]

            public init(
                activeFileURL: URL?,
                recentFilePaths: [String],
                successfulFilePaths: [String],
                previewStartCountsByFilePath: [String: Int]
            ) {
                self.activeFileURL = activeFileURL
                self.recentFilePaths = recentFilePaths
                self.successfulFilePaths = successfulFilePaths
                self.previewStartCountsByFilePath = previewStartCountsByFilePath
            }
        }

        public struct RankedPreview: Sendable {
            public let preview: LumiPreviewPackage.PreviewDiscovery
            public let score: Int
            public let reasons: [String]

            public init(
                preview: LumiPreviewPackage.PreviewDiscovery,
                score: Int,
                reasons: [String]
            ) {
                self.preview = preview
                self.score = score
                self.reasons = reasons
            }
        }

        public init() {}

        public func rank(
            _ previews: [LumiPreviewPackage.PreviewDiscovery],
            context: Context
        ) -> [RankedPreview] {
            previews
                .map { preview in
                    let scoring = score(preview, context: context)
                    return RankedPreview(
                        preview: preview,
                        score: scoring.score,
                        reasons: scoring.reasons
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.score != rhs.score {
                        return lhs.score > rhs.score
                    }
                    if lhs.preview.sourceFileURL.path != rhs.preview.sourceFileURL.path {
                        return lhs.preview.sourceFileURL.path.localizedStandardCompare(
                            rhs.preview.sourceFileURL.path
                        ) == .orderedAscending
                    }
                    return lhs.preview.lineNumber < rhs.preview.lineNumber
                }
        }

        public func score(
            _ preview: LumiPreviewPackage.PreviewDiscovery,
            context: Context
        ) -> (score: Int, reasons: [String]) {
            let path = preview.sourceFileURL.standardizedFileURL.path
            let directoryPath = preview.sourceFileURL.deletingLastPathComponent().standardizedFileURL.path
            let activePath = context.activeFileURL?.standardizedFileURL.path
            let activeDirectoryPath = context.activeFileURL?.deletingLastPathComponent().standardizedFileURL.path
            var score = 0
            var reasons: [String] = []

            if path == activePath {
                score += 1_000
                reasons.append("current")
            } else if directoryPath == activeDirectoryPath {
                score += 250
                reasons.append("same-dir")
            }

            if let rank = context.recentFilePaths.firstIndex(of: path) {
                score += max(150 - rank * 10, 20)
                reasons.append("recent")
            }

            if let rank = context.successfulFilePaths.firstIndex(of: path) {
                score += max(120 - rank * 8, 16)
                reasons.append("successful")
            }

            if let startCount = context.previewStartCountsByFilePath[path], startCount > 0 {
                score += min(startCount * 15, 150)
                reasons.append("starts:\(startCount)")
            }

            return (score, reasons.isEmpty ? ["indexed"] : reasons)
        }
    }
}

public typealias ProjectPreviewPrewarmRanker = LumiHotPreviewPackage.ProjectPreviewPrewarmRanker
