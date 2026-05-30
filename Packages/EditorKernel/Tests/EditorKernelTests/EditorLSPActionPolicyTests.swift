import Testing
import Foundation
import LanguageServerProtocol
@testable import EditorKernel

@Suite("EditorLSPActionPolicy")
struct EditorLSPActionPolicyTests {
    @Test("language id mapping is case-insensitive")
    func languageIDMapping() {
        #expect(EditorLSPActionPolicy.languageID(forFileExtension: "SWIFT") == "swift")
        #expect(EditorLSPActionPolicy.languageID(forFileExtension: "tsx") == "typescript")
        #expect(EditorLSPActionPolicy.languageID(forFileExtension: "unknown") == nil)
    }

    @Test("jump kind maps to status message key")
    func statusMessageKeyMapping() {
        #expect(EditorLSPActionPolicy.statusMessageKey(for: .definition) == .findingDefinition)
        #expect(EditorLSPActionPolicy.statusMessageKey(for: .declaration) == .findingDeclaration)
        #expect(EditorLSPActionPolicy.statusMessageKey(for: .typeDefinition) == .findingTypeDefinition)
        #expect(EditorLSPActionPolicy.statusMessageKey(for: .implementation) == .findingImplementation)
    }

    @Test("reference results sort by path line column")
    func referenceResultSorting() {
        let currentFile = URL(fileURLWithPath: "/tmp/project/main.swift")
        let projectRoot = "/tmp/project"
        let locations: [Location] = [
            .init(
                uri: "file:///tmp/project/B.swift",
                range: .init(
                    start: .init(line: 9, character: 2),
                    end: .init(line: 9, character: 5)
                )
            ),
            .init(
                uri: "file:///tmp/project/A.swift",
                range: .init(
                    start: .init(line: 2, character: 4),
                    end: .init(line: 2, character: 8)
                )
            )
        ]

        let results = EditorLSPActionPolicy.referenceResults(
            from: locations,
            currentFileURL: currentFile,
            relativeFilePath: "main.swift",
            projectRootPath: projectRoot,
            previewLine: { _, _ in "preview" }
        )

        #expect(results.count == 2)
        #expect(results[0].path == "A.swift")
        #expect(results[0].line == 3)
        #expect(results[1].path == "B.swift")
        #expect(results[1].line == 10)
    }

    @Test("reference display paths reject sibling projects with shared prefixes")
    func referenceResultDisplayPathRejectsSiblingProjectPrefix() {
        let currentFile = URL(fileURLWithPath: "/tmp/project/main.swift")
        let locations: [Location] = [
            .init(
                uri: "file:///tmp/project2/Sources/Other.swift",
                range: .init(
                    start: .init(line: 0, character: 0),
                    end: .init(line: 0, character: 5)
                )
            )
        ]

        let results = EditorLSPActionPolicy.referenceResults(
            from: locations,
            currentFileURL: currentFile,
            relativeFilePath: "main.swift",
            projectRootPath: "/tmp/project",
            previewLine: { _, _ in "preview" }
        )

        #expect(results.map(\.path) == ["Other.swift"])
    }
}
