import XCTest
@testable import GoEditorCore

final class GoEditorCoreTests: XCTestCase {
    func testProjectDetectorFindsNearestGoModFromFile() throws {
        let root = try makeTemporaryDirectory()
        let module = root.appendingPathComponent("service")
        let nested = module.appendingPathComponent("internal/api")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: module.appendingPathComponent("go.mod").path, contents: Data())
        let file = nested.appendingPathComponent("handler.go")
        FileManager.default.createFile(atPath: file.path, contents: Data())

        let project = GoProjectDetector.findProject(from: file)

        XCTAssertEqual(project?.rootPath, module.path)
        XCTAssertEqual(project?.moduleFilePath, module.appendingPathComponent("go.mod").path)
    }

    func testProjectDetectorReportsWorkspaceFileAboveModule() throws {
        let root = try makeTemporaryDirectory()
        let module = root.appendingPathComponent("apps/api")
        try FileManager.default.createDirectory(at: module, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: root.appendingPathComponent("go.work").path, contents: Data())
        FileManager.default.createFile(atPath: module.appendingPathComponent("go.mod").path, contents: Data())

        let project = GoProjectDetector.findProject(from: module)

        XCTAssertEqual(project?.rootPath, module.path)
        XCTAssertEqual(project?.workspaceFilePath, root.appendingPathComponent("go.work").path)
    }

    func testGoEnvSnapshotBuildsProcessEnvironment() {
        let snapshot = GoEnvResolver.Snapshot(
            goPath: "/usr/bin/go",
            goplsPath: "/usr/bin/gopls",
            gofumptPath: nil,
            dlvPath: "/usr/bin/dlv",
            goRoot: "/usr/local/go",
            goPathValue: "/Users/test/go"
        )

        XCTAssertEqual(snapshot.processEnvironment, [
            "GOROOT": "/usr/local/go",
            "GOPATH": "/Users/test/go",
        ])
    }

    func testGoLSPConfigBuildsServerOptionsAndEnvironment() {
        let config = GoLSPConfig(
            goplsPath: "/usr/local/bin/gopls",
            goPath: "/usr/local/bin/go",
            goRoot: "/usr/local/go",
            goPathValue: "/Users/test/go"
        )

        XCTAssertEqual(config.goplsPath, "/usr/local/bin/gopls")
        XCTAssertEqual(config.serverArguments, ["serve"])
        XCTAssertEqual(config.processEnvironment["GOROOT"], "/usr/local/go")
        XCTAssertEqual(config.processEnvironment["GOPATH"], "/Users/test/go")
        XCTAssertEqual(config.initializationOptions["gopls.staticcheck"], "true")
        XCTAssertEqual(config.initializationOptions["gopls.completeUnimported"], "true")
        XCTAssertEqual(config.initializationOptions["gopls.codelenses.test"], "true")
        XCTAssertEqual(config.initializationOptions["gopls.hints.parameterNames"], "true")
    }

    func testGoCompletionPipelineFiltersKeywordsAndSnippets() {
        let suggestions = GoCompletionPipeline.suggestions(prefix: "func")

        XCTAssertTrue(suggestions.contains { $0.label == "func" })
        XCTAssertTrue(suggestions.contains { $0.label == "func main" })
        XCTAssertFalse(suggestions.contains { $0.label == "package main" })
    }

    func testGoCompletionPipelinePrefersTypesInTypeContext() {
        let suggestions = GoCompletionPipeline.suggestions(prefix: "str", isTypeContext: true)

        XCTAssertTrue(suggestions.contains { $0.label == "string" })
    }

    func testGoToolCommandArguments() {
        XCTAssertEqual(GoBuildCommand.allPackages.command, "build")
        XCTAssertEqual(GoBuildCommand.allPackages.arguments, ["-v", "./..."])
        XCTAssertEqual(GoTestCommand.allPackagesJSON.command, "test")
        XCTAssertEqual(GoTestCommand.allPackagesJSON.arguments, ["-v", "-json", "./..."])
        XCTAssertEqual(GoFmtCommand.allPackages.command, "fmt")
        XCTAssertEqual(GoFmtCommand.allPackages.arguments, ["./..."])
        XCTAssertEqual(GoModCommand.tidy.command, "mod")
        XCTAssertEqual(GoModCommand.tidy.arguments, ["tidy"])
    }

    func testGoBuildIssueParsesErrorsWarningsAndIgnoresPackageHeaders() {
        XCTAssertEqual(
            GoBuildIssue.parse(from: "cmd/server/main.go:12:7: undefined: missing"),
            GoBuildIssue(file: "cmd/server/main.go", line: 12, column: 7, severity: .error, message: "undefined: missing")
        )
        XCTAssertEqual(
            GoBuildIssue.parse(from: "internal/api/handler.go:44:2: warning: unreachable code"),
            GoBuildIssue(file: "internal/api/handler.go", line: 44, column: 2, severity: .warning, message: "unreachable code")
        )
        XCTAssertNil(GoBuildIssue.parse(from: "# example.com/app"))
    }

    func testGoBuildOutputParserMergesOutputAndParsesIssues() {
        let stderr = """
        # example.com/app
        cmd/server/main.go:12:7: undefined: missing
        internal/api/handler.go:44:2: warning: unreachable code
        """

        let result = GoBuildOutputParser.parse(stdout: "example.com/app/internal/api", stderr: stderr)

        XCTAssertEqual(result.lines.count, 4)
        XCTAssertEqual(result.issues.count, 2)
        XCTAssertEqual(result.issues[0].severity, .error)
        XCTAssertEqual(result.issues[1].severity, .warning)
    }

    func testGoTestOutputParserParsesAndDeduplicatesFinalEventsByPackageAndName() {
        let output = """
        {"Action":"run","Package":"example.com/app","Test":"TestAlpha"}
        {"Action":"pass","Package":"example.com/app","Test":"TestAlpha","Elapsed":0.01}
        {"Action":"run","Package":"example.com/app/internal","Test":"TestAlpha"}
        {"Action":"fail","Package":"example.com/app/internal","Test":"TestAlpha","Elapsed":0.02}
        """

        let parsed = GoTestOutputParser.parse(output: output)
        let events = GoTestOutputParser.finalEvents(from: output)

        XCTAssertEqual(parsed.count, 4)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.map(\.package), ["example.com/app", "example.com/app/internal"])
        XCTAssertEqual(events.map(\.status), [.pass, .fail])
    }

    func testGoTestOutputParserKeepsPackageLevelCompileFailures() {
        let output = """
        {"Action":"output","Package":"example.com/app","Output":"# example.com/app\\n"}
        {"Action":"output","Package":"example.com/app","Output":"./main.go:4:2: undefined: missing\\n"}
        {"Action":"fail","Package":"example.com/app","Elapsed":0.01}
        """

        let parsed = GoTestOutputParser.parse(output: output)
        let events = GoTestOutputParser.finalEvents(from: output)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].package, "example.com/app")
        XCTAssertEqual(events[0].test, "Package failure")
        XCTAssertEqual(events[0].status, .fail)
    }

    func testGoTestOutputParserDoesNotDuplicatePackageFailWhenTestsFailed() {
        let output = """
        {"Action":"run","Package":"example.com/app","Test":"TestAlpha"}
        {"Action":"fail","Package":"example.com/app","Test":"TestAlpha","Elapsed":0.02}
        {"Action":"fail","Package":"example.com/app","Elapsed":0.03}
        """

        let events = GoTestOutputParser.finalEvents(from: output)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].test, "TestAlpha")
        XCTAssertEqual(events[0].status, .fail)
    }

    func testGoInlayHintPipelineSettingsAndRequestGate() {
        let pipeline = GoInlayHintPipeline.default

        XCTAssertEqual(pipeline.goplsSettings["gopls.hints.parameterNames"], "true")
        XCTAssertTrue(GoInlayHintPipeline.shouldRequestHints(languageId: "go", isLargeFileMode: false, visibleLineCount: 20))
        XCTAssertFalse(GoInlayHintPipeline.shouldRequestHints(languageId: "swift", isLargeFileMode: false, visibleLineCount: 20))
        XCTAssertFalse(GoInlayHintPipeline.shouldRequestHints(languageId: "go", isLargeFileMode: true, visibleLineCount: 20))
        XCTAssertFalse(GoInlayHintPipeline.shouldRequestHints(languageId: "go", isLargeFileMode: false, visibleLineCount: 0))
    }

    func testGoFormatOnSavePolicyPrefersLSPThenGofumptThenGofmt() {
        XCTAssertEqual(
            GoFormatOnSavePolicy.resolve(
                languageId: "go",
                editorFormatOnSave: true,
                env: snapshot(goPath: "/usr/bin/go", goplsPath: "/usr/bin/gopls", gofumptPath: "/usr/bin/gofumpt")
            ),
            GoFormatOnSavePolicy(isEnabled: true, formatter: .lsp)
        )
        XCTAssertEqual(
            GoFormatOnSavePolicy.resolve(
                languageId: "go",
                editorFormatOnSave: true,
                env: snapshot(goPath: "/usr/bin/go", goplsPath: nil, gofumptPath: "/usr/bin/gofumpt")
            ),
            GoFormatOnSavePolicy(isEnabled: true, formatter: .gofumpt)
        )
        XCTAssertEqual(
            GoFormatOnSavePolicy.resolve(
                languageId: "go",
                editorFormatOnSave: true,
                env: snapshot(goPath: "/usr/bin/go", goplsPath: nil, gofumptPath: nil)
            ),
            GoFormatOnSavePolicy(isEnabled: true, formatter: .gofmt)
        )
        XCTAssertEqual(
            GoFormatOnSavePolicy.resolve(
                languageId: "go",
                editorFormatOnSave: false,
                env: snapshot(goPath: "/usr/bin/go", goplsPath: "/usr/bin/gopls", gofumptPath: nil)
            ),
            GoFormatOnSavePolicy(isEnabled: false, formatter: .lsp)
        )
    }

    func testGoCodeLensPipelineFindsRunnableTests() {
        let content = """
        package api

        func TestHandler(t *testing.T) {}
        func helper() {}
        func BenchmarkHandler(b *testing.B) {}
        func FuzzParser(f *testing.F) {}
        func ExampleHandler() {}
        """

        let lenses = GoCodeLensPipeline.lenses(in: content, languageId: "go")

        XCTAssertEqual(lenses.map(\.line), [2, 4, 5, 6])
        XCTAssertEqual(lenses.first?.commandId, "go.test")
        XCTAssertTrue(GoCodeLensPipeline.lenses(in: content, languageId: "swift").isEmpty)
    }

    func testDelveAdapterBuildsDebugFileCommandLine() {
        let env = snapshot(
            goPath: "/usr/bin/go",
            goplsPath: "/usr/bin/gopls",
            gofumptPath: nil,
            dlvPath: "/usr/bin/dlv",
            goRoot: "/usr/local/go",
            goPathValue: "/Users/test/go"
        )
        let config = DelveAdapter.defaultLaunch(
            fileURL: URL(fileURLWithPath: "/tmp/app/main.go"),
            projectPath: "/tmp/app",
            env: env
        )

        let command = DelveAdapter.commandLine(for: config, dlvPath: env.dlvPath)

        XCTAssertEqual(command?.executable, "/usr/bin/dlv")
        XCTAssertEqual(command?.arguments, [
            "debug",
            "--headless",
            "--listen=127.0.0.1:0",
            "--api-version=2",
            "/tmp/app/main.go",
        ])
        XCTAssertEqual(config.environment["GOROOT"], "/usr/local/go")
        XCTAssertEqual(config.environment["GOPATH"], "/Users/test/go")
    }

    func testDelveAdapterBuildsPackageAndTestCommandLines() {
        let debugPackage = DelveAdapter.defaultLaunch(fileURL: nil, projectPath: "/tmp/app", env: snapshot())
        let testPackage = DelveAdapter.testLaunch(projectPath: "/tmp/app", env: snapshot())

        XCTAssertEqual(DelveAdapter.commandLine(for: debugPackage, dlvPath: "/usr/bin/dlv")?.arguments, [
            "debug",
            "--headless",
            "--listen=127.0.0.1:0",
            "--api-version=2",
            "./...",
        ])
        XCTAssertEqual(DelveAdapter.commandLine(for: testPackage, dlvPath: "/usr/bin/dlv")?.arguments, [
            "test",
            "--headless",
            "--listen=127.0.0.1:0",
            "--api-version=2",
            "./...",
        ])
    }

    func testDelveAdapterReturnsNilWhenDlvMissing() {
        let config = DelveAdapter.defaultLaunch(fileURL: nil, projectPath: "/tmp/app", env: snapshot())

        XCTAssertNil(DelveAdapter.commandLine(for: config, dlvPath: nil))
    }

    private func snapshot(
        goPath: String? = "/usr/bin/go",
        goplsPath: String? = "/usr/bin/gopls",
        gofumptPath: String? = nil,
        dlvPath: String? = "/usr/bin/dlv",
        goRoot: String? = nil,
        goPathValue: String? = nil
    ) -> GoEnvResolver.Snapshot {
        GoEnvResolver.Snapshot(
            goPath: goPath,
            goplsPath: goplsPath,
            gofumptPath: gofumptPath,
            dlvPath: dlvPath,
            goRoot: goRoot,
            goPathValue: goPathValue
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoEditorCoreTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
