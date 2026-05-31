import Testing
import Foundation
@testable import PluginJSEditor

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func packageJSONParserReadsPeerAndOptionalDependenciesForInference() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    try """
    {
      "name": "component-library",
      "peerDependencies": {
        "vue": "^3.4.0",
        "vitest": "^1.6.0"
      },
      "optionalDependencies": {
        "vite": "^5.0.0"
      }
    }
    """.write(to: directory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

    let package = try #require(PackageJSONParser.parse(projectPath: directory.path))

    #expect(package.peerDependencies["vue"] == "^3.4.0")
    #expect(package.optionalDependencies["vite"] == "^5.0.0")
    #expect(package.inferredFramework == .vue)
    #expect(package.inferredBuilder == .vite)
    #expect(package.inferredTestFramework == .vitest)
}

@Test func workspaceDetectorUsesTurboFromOptionalDependencies() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    try """
    {
      "name": "workspace-root",
      "optionalDependencies": {
        "turbo": "^2.0.0"
      }
    }
    """.write(to: directory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

    let appDirectory = directory.appendingPathComponent("apps/web", isDirectory: true)
    try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
    try """
    {
      "name": "web"
    }
    """.write(to: appDirectory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

    let workspace = try #require(WorkspaceDetector.detect(projectPath: directory.path))
    let expectedPaths = [directory, appDirectory].map { $0.resolvingSymlinksInPath().path }.sorted()

    #expect(workspace.packagePaths == expectedPaths)
}

@Test func envResolverUsesPackageManagerFieldWithoutLockfile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    try """
    {
      "name": "pnpm-project",
      "packageManager": "pnpm@9.15.0"
    }
    """.write(to: directory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

    #expect(JSEnvResolver.detectPackageManager(projectPath: directory.path) == .pnpm)
}

@Test func envResolverPrefersLockfileOverPackageManagerField() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    try """
    {
      "name": "lockfile-project",
      "packageManager": "npm@10.0.0"
    }
    """.write(to: directory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
    try "".write(to: directory.appendingPathComponent("yarn.lock"), atomically: true, encoding: .utf8)

    #expect(JSEnvResolver.detectPackageManager(projectPath: directory.path) == .yarn)
}

@Test func tsConfigResolverParsesJSONCCommentsAndTrailingCommas() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let configURL = directory.appendingPathComponent("tsconfig.json")
    try """
    {
      // Common in tsconfig files generated or edited by users.
      "compilerOptions": {
        "baseUrl": ".",
        "paths": {
          "@/*": ["src/*"],
        },
        "jsx": "react-jsx",
        "strict": true,
      },
    }
    """.write(to: configURL, atomically: true, encoding: .utf8)

    let config = try #require(TSConfigResolver.parse(fileURL: configURL))

    #expect(config.baseURL == ".")
    #expect(config.paths["@/*"] == ["src/*"])
    #expect(config.jsx == "react-jsx")
    #expect(config.strict == true)
}

@Test func tsConfigResolverKeepsCommentMarkersInsideStrings() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let configURL = directory.appendingPathComponent("jsconfig.json")
    try #"""
    {
      "compilerOptions": {
        "baseUrl": "https://example.com/project",
        "paths": {
          "/*": ["src/*,literal"],
        }
      }
    }
    """#.write(to: configURL, atomically: true, encoding: .utf8)

    let config = try #require(TSConfigResolver.parse(fileURL: configURL))

    #expect(config.baseURL == "https://example.com/project")
    #expect(config.paths["/*"] == ["src/*,literal"])
}

@Test func sourceMapResolverUsesLastMappingURLMarker() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let generatedURL = directory.appendingPathComponent("bundle.js")
    try """
    const text = "sourceMappingURL=wrong.map";
    //# sourceMappingURL=bundle.js.map
    """.write(to: generatedURL, atomically: true, encoding: .utf8)

    let sourceMapURL = try #require(SourceMapResolver.sourceMapURL(for: generatedURL))

    #expect(sourceMapURL.lastPathComponent == "bundle.js.map")
}

@Test func sourceMapResolverResolvesRelativeMappingURLAgainstGeneratedFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let generatedURL = directory.appendingPathComponent("dist/bundle.js")
    try FileManager.default.createDirectory(at: generatedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try """
    console.log("ready");
    //# sourceMappingURL=maps/bundle.js.map
    """.write(to: generatedURL, atomically: true, encoding: .utf8)

    let sourceMapURL = try #require(SourceMapResolver.sourceMapURL(for: generatedURL))

    #expect(sourceMapURL.isFileURL)
    #expect(sourceMapURL.path == generatedURL.deletingLastPathComponent().appendingPathComponent("maps/bundle.js.map").path)
}

@Test func sourceMapResolverReadsMappingURLFromUTF16GeneratedFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let generatedURL = directory.appendingPathComponent("dist/bundle.js")
    try FileManager.default.createDirectory(at: generatedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try """
    console.log("ready");
    //# sourceMappingURL=maps/bundle.js.map
    """.write(to: generatedURL, atomically: true, encoding: .utf16)

    let sourceMapURL = try #require(SourceMapResolver.sourceMapURL(for: generatedURL))

    #expect(sourceMapURL.path == generatedURL.deletingLastPathComponent().appendingPathComponent("maps/bundle.js.map").path)
}

@Test func sourceMapResolverKeepsAbsoluteMappingURL() throws {
    let generatedURL = URL(fileURLWithPath: "/tmp/dist/bundle.js")

    let sourceMapURL = try #require(SourceMapResolver.resolveSourceMapTail("https://example.com/bundle.js.map", relativeTo: generatedURL))

    #expect(sourceMapURL.absoluteString == "https://example.com/bundle.js.map")
}

@Test func sourceMapResolverKeepsQuotedMappingURLWithSpaces() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let generatedURL = directory.appendingPathComponent("dist/bundle.js")
    try FileManager.default.createDirectory(at: generatedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try """
    console.log("ready");
    //# sourceMappingURL="maps/bundle debug.js.map"
    """.write(to: generatedURL, atomically: true, encoding: .utf8)

    let sourceMapURL = try #require(SourceMapResolver.sourceMapURL(for: generatedURL))

    #expect(sourceMapURL.path == generatedURL.deletingLastPathComponent().appendingPathComponent("maps/bundle debug.js.map").path)
}

@Test func sourceMapResolverAcceptsUnescapedFileURLMappingURLWithSpaces() throws {
    let generatedURL = URL(fileURLWithPath: "/tmp/dist/bundle.js")
    let sourceMapURL = try #require(SourceMapResolver.resolveSourceMapTail(
        "file:///tmp/project/My Map.js.map",
        relativeTo: generatedURL
    ))

    #expect(sourceMapURL.path == "/tmp/project/My Map.js.map")
}

@Test func buildOutputAdapterKeepsStdoutAndStderrLineBoundaryWithoutTrailingNewline() throws {
    let issues = BuildOutputAdapter.issues(
        stdout: "src/app.ts:2:3 - warning unused variable",
        stderr: "src/app.ts:1:1 - error missing semicolon"
    )

    #expect(issues.count == 2)
    #expect(issues.map(\.severity) == [.error, .warning])
    #expect(issues.map(\.line) == [1, 2])
}

@Test func testOutputParserKeepsStreamBoundaryWithoutTrailingNewline() throws {
    let output = BuildOutputAdapter.combinedOutput(
        stdout: "✓ renders dashboard (20ms)",
        stderr: "FAIL failing.test.ts"
    )

    let events = TestOutputParser.parse(output: output)

    #expect(events.count == 2)
    #expect(events.map(\.status) == [.failed, .passed])
    #expect(events.map(\.name) == ["failing.test.ts", "renders dashboard (20ms)"])
}

@Test func scriptTaskRunnerHandlesLargeProcessOutput() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let result = await ScriptTaskRunner().runExecutable(
        "sh",
        arguments: ["-c", "for i in $(seq 1 300); do printf 'stdout-%03d-%0512d\\n' \"$i\" 0; printf 'stderr-%03d-%0512d\\n' \"$i\" 0 >&2; done"],
        projectPath: directory.path
    )

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("stdout-300-"))
    #expect(result.stderr.contains("stderr-300-"))
}

@Test func scriptTaskRunnerCancelStopsRunningProcessPromptly() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let runner = ScriptTaskRunner()
    let start = Date()
    let task = Task {
        await runner.runExecutable(
            "sh",
            arguments: ["-c", "sleep 5; echo should-not-complete"],
            projectPath: directory.path
        )
    }

    try await Task.sleep(nanoseconds: 100_000_000)
    await runner.cancel()
    let result = await task.value

    #expect(Date().timeIntervalSince(start) < 2)
    #expect(result.exitCode != 0)
    #expect(!result.stdout.contains("should-not-complete"))
}

@MainActor
@Test func jsTaskManagerCancelStopsRunningScriptPromptly() async throws {
    guard JSEnvResolver.findCommand("npm") != nil else { return }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    try """
    {
      "scripts": {
        "slow": "node -e \\"setTimeout(() => console.log('should-not-complete'), 5000)\\""
      }
    }
    """.write(to: directory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

    let manager = JSTaskManager()
    let start = Date()
    let task = Task { @MainActor in
        await manager.run(script: "slow", projectPath: directory.path)
    }

    try await Task.sleep(nanoseconds: 100_000_000)
    manager.cancel()
    await task.value

    #expect(Date().timeIntervalSince(start) < 2)
    #expect(manager.state == .cancelled)
    #expect(!manager.outputLines.contains { $0.contains("should-not-complete") })
}

@Test func runtimeBridgeHandlesLargeNodeOutput() async throws {
    guard JSEnvResolver.nodePath != nil else { return }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let scriptURL = directory.appendingPathComponent("large-output.js")
    try """
    for (let i = 1; i <= 300; i += 1) {
      console.log(`stdout-${String(i).padStart(3, "0")}-${"x".repeat(512)}`);
      console.error(`stderr-${String(i).padStart(3, "0")}-${"y".repeat(512)}`);
    }
    """.write(to: scriptURL, atomically: true, encoding: .utf8)

    let result = await RuntimeBridge().runNode(script: scriptURL.path, projectPath: directory.path)

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("stdout-300-"))
    #expect(result.stderr.contains("stderr-300-"))
}

@Test func jsIssueFileResolverKeepsFileURLsAndExpandsLocalPaths() {
    let projectRoot = "/tmp/project"

    #expect(JSIssueFileResolver.url(for: "file:///tmp/project/src/app.ts", projectRoot: projectRoot).path == "/tmp/project/src/app.ts")
    #expect(JSIssueFileResolver.url(for: "file:///tmp/project/src/app with space.ts", projectRoot: projectRoot).path == "/tmp/project/src/app with space.ts")
    #expect(JSIssueFileResolver.url(for: "~/src/app.ts", projectRoot: projectRoot).path == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("src/app.ts").path)
    #expect(JSIssueFileResolver.url(for: "src/app.ts", projectRoot: projectRoot).path == "/tmp/project/src/app.ts")
}
