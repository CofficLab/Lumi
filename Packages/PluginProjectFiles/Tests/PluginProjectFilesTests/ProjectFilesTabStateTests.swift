import Foundation
import PluginProjectFiles
import Testing

struct ProjectFilesTabStateTests {
    @Test("projects ProjectProviding open files in source order")
    func projectsOpenFiles() {
        let first = URL(fileURLWithPath: "/tmp/Main.swift")
        let current = URL(fileURLWithPath: "/tmp/Helper.swift")
        let duplicate = URL(fileURLWithPath: "/tmp/./Main.swift")

        let projection = ProjectFilesTabState(
            openFileURLs: [first, duplicate, current],
            currentFileURL: current
        )

        #expect(projection.fileURLs == [first.standardizedFileURL, current.standardizedFileURL])
        #expect(projection.activeFileURL == current.standardizedFileURL)
    }

    @Test("empty ProjectProviding state produces no project file tabs")
    func emptyState() {
        let projection = ProjectFilesTabState(openFileURLs: [], currentFileURL: nil)

        #expect(projection.fileURLs.isEmpty)
        #expect(projection.activeFileURL == nil)
    }
}
