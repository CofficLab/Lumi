import Foundation
import Testing
@testable import PluginVueEditor

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func cssModulesParserHandlesMultiLineRules() {
    let css = """
    .container, .wrapper {
        display: flex;
        color: red;
    }
    """

    let entries = CSSModulesTypeGenerator.parseClassNames(from: css)

    #expect(entries.map(\.name) == ["container", "wrapper"])
    #expect(entries.first?.properties == ["display: flex", "color: red"])
}

@Test func cssModulesParserHandlesSingleLineRules() {
    let css = ".button { color: blue; font-weight: 600; }"

    let entries = CSSModulesTypeGenerator.parseClassNames(from: css)

    #expect(entries.count == 1)
    #expect(entries.first?.name == "button")
    #expect(entries.first?.properties == ["color: blue", "font-weight: 600"])
}

@Test func vueScannerRelativePathOnlyDropsProjectRootPrefix() throws {
    let projectURL = try makeTemporaryVueProject()
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let nestedDirectory = projectURL
        .appendingPathComponent("src/components/tmp")
        .appendingPathComponent(projectURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
    let componentURL = nestedDirectory.appendingPathComponent("user-card.vue")
    try "<template />".write(to: componentURL, atomically: true, encoding: .utf8)

    let entries = VueProjectScanner.scan(projectPath: projectURL.path)

    #expect(entries.first?.name == "UserCard")
    #expect(entries.first?.relativePath == "src/components/tmp/\(projectURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/user-card.vue")
}

@Test func vueScannerRelativePathRejectsSiblingWithSharedPrefix() {
    let fileURL = URL(fileURLWithPath: "/tmp/vue-app-copy/src/App.vue")

    #expect(VueProjectScanner.relativePath(for: fileURL, rootPath: "/tmp/vue-app") == "App.vue")
}

@Test func vueScannerImportPathIsRelativeToCurrentFile() {
    let component = VueProjectScanner.ComponentEntry(
        name: "UserCard",
        path: "/tmp/vue-app/src/components/UserCard.vue",
        relativePath: "src/components/UserCard.vue"
    )
    let currentFile = URL(fileURLWithPath: "/tmp/vue-app/src/views/Home.vue")

    #expect(VueProjectScanner.importPath(for: component, relativeTo: currentFile) == "../components/UserCard")
}

@Test func vueScannerImportPathUsesDotSlashForSiblingComponent() {
    let component = VueProjectScanner.ComponentEntry(
        name: "UserCard",
        path: "/tmp/vue-app/src/views/UserCard.vue",
        relativePath: "src/views/UserCard.vue"
    )
    let currentFile = URL(fileURLWithPath: "/tmp/vue-app/src/views/Home.vue")

    #expect(VueProjectScanner.importPath(for: component, relativeTo: currentFile) == "./UserCard")
}

private func makeTemporaryVueProject() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginVueEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
