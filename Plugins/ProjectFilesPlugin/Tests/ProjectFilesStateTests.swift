import Foundation
import Testing
@testable import ProjectFilesPlugin

@Suite("Project Files State")
struct ProjectFilesStateTests {
    @Test
    func visibleFilesIncludeCurrentFileOnce() {
        let openFiles = [
            URL(fileURLWithPath: "/tmp/Project/Sources/Main.swift"),
            URL(fileURLWithPath: "/tmp/Project/Sources/Helper.swift")
        ]
        let currentFile = URL(fileURLWithPath: "/tmp/Project/Sources/Main.swift")

        let visible = ProjectFilesState.visibleFileURLs(
            openFileURLs: openFiles,
            currentFileURL: currentFile
        )

        #expect(visible.count == 2)
        #expect(visible[0].path == "/tmp/Project/Sources/Main.swift")
        #expect(visible[1].path == "/tmp/Project/Sources/Helper.swift")
    }

    @Test
    func visibleFilesAppendCurrentFileWhenMissing() {
        let openFiles = [
            URL(fileURLWithPath: "/tmp/Project/Sources/Helper.swift")
        ]
        let currentFile = URL(fileURLWithPath: "/tmp/Project/Sources/Main.swift")

        let visible = ProjectFilesState.visibleFileURLs(
            openFileURLs: openFiles,
            currentFileURL: currentFile
        )

        #expect(visible.count == 2)
        #expect(visible.map(\.path) == [
            "/tmp/Project/Sources/Helper.swift",
            "/tmp/Project/Sources/Main.swift"
        ])
    }
}
