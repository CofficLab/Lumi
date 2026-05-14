import Foundation
import LumiPreviewKit
import Testing
@testable import LumiHotPreviewKit

@Suite("ProjectPreviewPrewarmRanker")
struct ProjectPreviewPrewarmRankerTests {
    @Test("prioritizes current file before history signals")
    func prioritizesCurrentFileBeforeHistorySignals() {
        let ranker = ProjectPreviewPrewarmRanker()
        let current = makeDiscovery(path: "/tmp/App/Sources/Current.swift", line: 20)
        let frequent = makeDiscovery(path: "/tmp/App/Sources/Other.swift", line: 10)
        let frequentPath = frequent.sourceFileURL.standardizedFileURL.path

        let ranked = ranker.rank(
            [frequent, current],
            context: .init(
                activeFileURL: current.sourceFileURL,
                recentFilePaths: [frequentPath],
                successfulFilePaths: [frequentPath],
                previewStartCountsByFilePath: [frequentPath: 20]
            )
        )

        #expect(ranked.map(\.preview.id) == [current.id, frequent.id])
        #expect(ranked[0].reasons.contains("current"))
    }

    @Test("combines same directory, recent, success, and start count signals")
    func combinesWeightedSignals() {
        let ranker = ProjectPreviewPrewarmRanker()
        let activeURL = URL(fileURLWithPath: "/tmp/App/Sources/Active.swift")
        let weighted = makeDiscovery(path: "/tmp/App/Sources/Weighted.swift", line: 10)
        let indexed = makeDiscovery(path: "/tmp/App/Features/Indexed.swift", line: 10)
        let weightedPath = weighted.sourceFileURL.standardizedFileURL.path

        let ranked = ranker.rank(
            [indexed, weighted],
            context: .init(
                activeFileURL: activeURL,
                recentFilePaths: [weightedPath],
                successfulFilePaths: [weightedPath],
                previewStartCountsByFilePath: [weightedPath: 4]
            )
        )

        #expect(ranked.map(\.preview.id) == [weighted.id, indexed.id])
        #expect(ranked[0].score == 580)
        #expect(ranked[0].reasons == ["same-dir", "recent", "successful", "starts:4"])
        #expect(ranked[1].reasons == ["indexed"])
    }

    @Test("uses path and line number as stable tie breakers")
    func usesStableTieBreakers() {
        let ranker = ProjectPreviewPrewarmRanker()
        let laterLine = makeDiscovery(path: "/tmp/App/B.swift", line: 20)
        let earlierLine = makeDiscovery(path: "/tmp/App/B.swift", line: 5)
        let earlierPath = makeDiscovery(path: "/tmp/App/A.swift", line: 100)

        let ranked = ranker.rank(
            [laterLine, earlierLine, earlierPath],
            context: .init(
                activeFileURL: nil,
                recentFilePaths: [],
                successfulFilePaths: [],
                previewStartCountsByFilePath: [:]
            )
        )

        #expect(ranked.map(\.preview.id) == [earlierPath.id, earlierLine.id, laterLine.id])
    }

    private func makeDiscovery(path: String, line: Int) -> LumiPreviewPackage.PreviewDiscovery {
        LumiPreviewPackage.PreviewDiscovery(
            id: "\(path):\(line)",
            title: "Preview",
            sourceFileURL: URL(fileURLWithPath: path),
            lineNumber: line,
            endLineNumber: line + 2,
            primaryTypeName: "Preview",
            bodySource: "Preview()",
            sourceText: nil
        )
    }
}
