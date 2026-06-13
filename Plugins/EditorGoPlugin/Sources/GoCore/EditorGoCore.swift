import Foundation
import ShellKit

public struct GoEnvResolver: Sendable {
    public struct Snapshot: Equatable, Sendable {
        public let goPath: String?
        public let goplsPath: String?
        public let gofumptPath: String?
        public let dlvPath: String?
        public let goRoot: String?
        public let goPathValue: String?

        public init(
            goPath: String?,
            goplsPath: String?,
            gofumptPath: String?,
            dlvPath: String?,
            goRoot: String?,
            goPathValue: String?
        ) {
            self.goPath = goPath
            self.goplsPath = goplsPath
            self.gofumptPath = gofumptPath
            self.dlvPath = dlvPath
            self.goRoot = goRoot
            self.goPathValue = goPathValue
        }

        public var processEnvironment: [String: String] {
            var env: [String: String] = [:]
            if let goRoot, !goRoot.isEmpty {
                env["GOROOT"] = goRoot
            }
            if let goPathValue, !goPathValue.isEmpty {
                env["GOPATH"] = goPathValue
            }
            return env
        }
    }

    public static var goPath: String? { findCommand("go") }
    public static var goplsPath: String? { findCommand("gopls") }
    public static var gofumptPath: String? { findCommand("gofumpt") }
    public static var dlvPath: String? { findCommand("dlv") }

    public static func resolveGOPATH() -> String? {
        goEnv("GOPATH")
    }

    public static func resolveGOROOT() -> String? {
        goEnv("GOROOT")
    }

    public static func resolveSnapshot() -> Snapshot {
        Snapshot(
            goPath: goPath,
            goplsPath: goplsPath,
            gofumptPath: gofumptPath,
            dlvPath: dlvPath,
            goRoot: resolveGOROOT(),
            goPathValue: resolveGOPATH()
        )
    }

    private static func findCommand(_ command: String) -> String? {
        Shell.findCommandSync(command)
    }

    private static func goEnv(_ key: String) -> String? {
        guard let go = goPath else { return nil }
        return runShellCommandSync(go, args: ["env", key])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runShellCommandSync(_ path: String, args: [String]) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = LockedStringBox()
        Task {
            let result = try? await Shell.execute(
                executable: path,
                arguments: args,
                options: ShellOptions(throwsOnError: false)
            )
            box.set(result?.exitCode == 0 ? result?.stdout : nil)
            semaphore.signal()
        }
        semaphore.wait()
        return box.get()
    }
}

private final class LockedStringBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    func set(_ value: String?) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    func get() -> String? {
        lock.lock()
        let result = value
        lock.unlock()
        return result
    }
}

public struct GoProjectDetector: Sendable {
    public struct Project: Equatable, Sendable {
        public let rootPath: String
        public let moduleFilePath: String
        public let workspaceFilePath: String?

        public init(rootPath: String, moduleFilePath: String, workspaceFilePath: String?) {
            self.rootPath = rootPath
            self.moduleFilePath = moduleFilePath
            self.workspaceFilePath = workspaceFilePath
        }
    }

    public static func findProjectRoot(from path: String) -> String? {
        findProject(from: path)?.rootPath
    }

    public static func findProjectRoot(from url: URL) -> String? {
        findProject(from: url)?.rootPath
    }

    public static func findProject(from path: String) -> Project? {
        findProject(from: URL(fileURLWithPath: path))
    }

    public static func findProject(from url: URL) -> Project? {
        let startURL = directoryURL(for: url)
        var currentURL = startURL

        while currentURL.path != "/" {
            let goModURL = currentURL.appendingPathComponent("go.mod")
            if FileManager.default.fileExists(atPath: goModURL.path) {
                return Project(
                    rootPath: currentURL.path,
                    moduleFilePath: goModURL.path,
                    workspaceFilePath: findWorkspaceFile(from: currentURL)
                )
            }
            currentURL.deleteLastPathComponent()
        }

        return nil
    }

    private static func directoryURL(for url: URL) -> URL {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        if values?.isDirectory == true {
            return url
        }
        return url.deletingLastPathComponent()
    }

    private static func findWorkspaceFile(from moduleRoot: URL) -> String? {
        var currentURL = moduleRoot
        while currentURL.path != "/" {
            let goWorkURL = currentURL.appendingPathComponent("go.work")
            if FileManager.default.fileExists(atPath: goWorkURL.path) {
                return goWorkURL.path
            }
            currentURL.deleteLastPathComponent()
        }
        return nil
    }
}

public protocol GoToolCommand: Sendable {
    var command: String { get }
    var arguments: [String] { get }
}

public struct GoBuildCommand: GoToolCommand, Equatable, Sendable {
    public var arguments: [String]
    public let command = "build"

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public static let allPackages = GoBuildCommand(arguments: ["-v", "./..."])
}

public struct GoTestCommand: GoToolCommand, Equatable, Sendable {
    public var arguments: [String]
    public let command = "test"

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public static let allPackagesJSON = GoTestCommand(arguments: ["-v", "-json", "./..."])
}

public struct GoFmtCommand: GoToolCommand, Equatable, Sendable {
    public var arguments: [String]
    public let command = "fmt"

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public static let allPackages = GoFmtCommand(arguments: ["./..."])
}

public struct GoModCommand: GoToolCommand, Equatable, Sendable {
    public enum Action: String, Sendable {
        case tidy
    }

    public let action: Action

    public init(action: Action) {
        self.action = action
    }

    public var command: String { "mod" }
    public var arguments: [String] { [action.rawValue] }

    public static let tidy = GoModCommand(action: .tidy)
}

public struct GoRunResult: Equatable, Sendable {
    public let exitCode: Int
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    public var isSuccess: Bool { exitCode == 0 }
}

public struct GoBuildIssue: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let file: String
    public let line: Int
    public let column: Int
    public let severity: Severity
    public let message: String

    public enum Severity: String, Sendable {
        case error
        case warning
    }

    public init(file: String, line: Int, column: Int, severity: Severity, message: String) {
        self.file = file
        self.line = line
        self.column = column
        self.severity = severity
        self.message = message
    }

    public static func == (lhs: GoBuildIssue, rhs: GoBuildIssue) -> Bool {
        lhs.file == rhs.file
            && lhs.line == rhs.line
            && lhs.column == rhs.column
            && lhs.severity == rhs.severity
            && lhs.message == rhs.message
    }

    public static func parse(from line: String) -> GoBuildIssue? {
        let pattern = #"^(.+?):(\d+):(\d+):\s*(error|warning):\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range) else {
            return parseWithoutSeverity(from: line)
        }

        let file = String(line[Range(match.range(at: 1), in: line)!])
        let lineNum = Int(String(line[Range(match.range(at: 2), in: line)!])) ?? 0
        let col = Int(String(line[Range(match.range(at: 3), in: line)!])) ?? 0
        let severityStr = String(line[Range(match.range(at: 4), in: line)!])
        let message = String(line[Range(match.range(at: 5), in: line)!])

        return GoBuildIssue(
            file: file,
            line: lineNum,
            column: col,
            severity: severityStr == "warning" ? .warning : .error,
            message: message
        )
    }

    private static func parseWithoutSeverity(from line: String) -> GoBuildIssue? {
        let pattern = #"^(.+?):(\d+):(\d+):\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }

        let file = String(line[Range(match.range(at: 1), in: line)!])
        let lineNum = Int(String(line[Range(match.range(at: 2), in: line)!])) ?? 0
        let col = Int(String(line[Range(match.range(at: 3), in: line)!])) ?? 0
        let message = String(line[Range(match.range(at: 4), in: line)!])

        guard !file.hasPrefix("#"), !message.isEmpty else { return nil }
        return GoBuildIssue(file: file, line: lineNum, column: col, severity: .error, message: message)
    }
}

public struct GoBuildOutputParser: Sendable {
    public struct Result: Equatable, Sendable {
        public let lines: [String]
        public let issues: [GoBuildIssue]

        public init(lines: [String], issues: [GoBuildIssue]) {
            self.lines = lines
            self.issues = issues
        }
    }

    public static func parse(stdout: String, stderr: String) -> Result {
        let lines = mergedLines(stdout: stdout, stderr: stderr)
        return Result(lines: lines, issues: lines.compactMap(GoBuildIssue.parse))
    }

    public static func mergedLines(stdout: String, stderr: String) -> [String] {
        (stderr + "\n" + stdout)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

public struct GoTestOutputParser: Sendable {
    private static let packageFailureTestName = "Package failure"

    public struct TestEvent: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public let test: String
        public let package: String
        public let status: TestStatus
        public let elapsed: Double?
        public let output: String?

        public init(test: String, package: String, status: TestStatus, elapsed: Double?, output: String?) {
            self.test = test
            self.package = package
            self.status = status
            self.elapsed = elapsed
            self.output = output
        }

        public static func == (lhs: TestEvent, rhs: TestEvent) -> Bool {
            lhs.test == rhs.test
                && lhs.package == rhs.package
                && lhs.status == rhs.status
                && lhs.elapsed == rhs.elapsed
                && lhs.output == rhs.output
        }
    }

    public enum TestStatus: String, Sendable {
        case pass
        case fail
        case skip
        case run
    }

    private struct TestJSONLine: Decodable {
        let Action: String?
        let Package: String?
        let Test: String?
        let Elapsed: Double?
        let Output: String?
    }

    public static func parse(output: String) -> [TestEvent] {
        var results: [TestEvent] = []
        let decoder = JSONDecoder()
        for line in output.components(separatedBy: .newlines) {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? decoder.decode(TestJSONLine.self, from: data),
                  let action = json.Action,
                  let status = TestStatus(rawValue: action) else {
                continue
            }

            let test: String
            if let parsedTest = json.Test {
                test = parsedTest
            } else if status == .fail, json.Package != nil {
                test = packageFailureTestName
            } else {
                continue
            }

            results.append(TestEvent(
                test: test,
                package: json.Package ?? "",
                status: status,
                elapsed: json.Elapsed,
                output: json.Output
            ))
        }
        return results
    }

    public static func finalEvents(from output: String) -> [TestEvent] {
        let parsed = parse(output: output)
        var deduped: [String: TestEvent] = [:]
        var packagesWithTestEvents: Set<String> = []
        var packageFailures: [String: TestEvent] = [:]

        for event in parsed where event.status != .run {
            if event.test == packageFailureTestName {
                packageFailures[event.package] = event
            } else {
                packagesWithTestEvents.insert(event.package)
                deduped["\(event.package)#\(event.test)"] = event
            }
        }

        for (package, event) in packageFailures where !packagesWithTestEvents.contains(package) {
            deduped["\(package)#\(event.test)"] = event
        }

        return Array(deduped.values).sorted {
            if $0.package == $1.package {
                return $0.test.localizedCaseInsensitiveCompare($1.test) == .orderedAscending
            }
            return $0.package.localizedCaseInsensitiveCompare($1.package) == .orderedAscending
        }
    }
}

public struct GoLSPConfig: Equatable, Sendable {
    public let goplsPath: String
    public let goPath: String?
    public let goRoot: String?
    public let goPathValue: String?
    public let enableStaticcheck: Bool
    public let enableCodeLens: Bool
    public let enableAnalyses: Bool

    public init(
        goplsPath: String,
        goPath: String?,
        goRoot: String?,
        goPathValue: String?,
        enableStaticcheck: Bool = true,
        enableCodeLens: Bool = true,
        enableAnalyses: Bool = true
    ) {
        self.goplsPath = goplsPath
        self.goPath = goPath
        self.goRoot = goRoot
        self.goPathValue = goPathValue
        self.enableStaticcheck = enableStaticcheck
        self.enableCodeLens = enableCodeLens
        self.enableAnalyses = enableAnalyses
    }

    public static func resolve(snapshot: GoEnvResolver.Snapshot = GoEnvResolver.resolveSnapshot()) -> GoLSPConfig? {
        guard let goplsPath = snapshot.goplsPath else { return nil }
        return GoLSPConfig(
            goplsPath: goplsPath,
            goPath: snapshot.goPath,
            goRoot: snapshot.goRoot,
            goPathValue: snapshot.goPathValue
        )
    }

    public var serverArguments: [String] { ["serve"] }

    public var processEnvironment: [String: String] {
        var env: [String: String] = [:]
        if let goRoot, !goRoot.isEmpty { env["GOROOT"] = goRoot }
        if let goPathValue, !goPathValue.isEmpty { env["GOPATH"] = goPathValue }
        return env
    }

    public var initializationOptions: [String: String] {
        var options: [String: String] = [
            "gopls.staticcheck": enableStaticcheck ? "true" : "false",
            "gopls.gofumpt": GoEnvResolver.gofumptPath == nil ? "false" : "true",
            "gopls.completeUnimported": "true",
            "gopls.usePlaceholders": "true",
        ]

        if enableAnalyses {
            options["gopls.analyses.unusedparams"] = "true"
            options["gopls.analyses.unusedwrite"] = "true"
            options["gopls.analyses.shadow"] = "true"
            options["gopls.analyses.nilness"] = "true"
        }

        if enableCodeLens {
            options["gopls.codelenses.generate"] = "true"
            options["gopls.codelenses.gc_details"] = "true"
            options["gopls.codelenses.test"] = "true"
            options["gopls.codelenses.tidy"] = "true"
            options["gopls.codelenses.upgrade_dependency"] = "true"
            options["gopls.codelenses.vendor"] = "true"
        }

        options.merge(GoInlayHintPipeline.default.goplsSettings) { _, new in new }
        return options
    }
}

public struct GoCompletionPipeline: Sendable {
    public struct Suggestion: Equatable, Sendable {
        public let label: String
        public let insertText: String
        public let detail: String

        public init(label: String, insertText: String, detail: String) {
            self.label = label
            self.insertText = insertText
            self.detail = detail
        }
    }

    public static func suggestions(prefix: String, isTypeContext: Bool = false) -> [Suggestion] {
        let normalizedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = keywordSuggestions
            + (isTypeContext ? predeclaredTypeSuggestions : [])
            + snippetSuggestions

        guard !normalizedPrefix.isEmpty else { return candidates }
        return candidates.filter { hasPrefix($0.label, normalizedPrefix) }
    }

    private static let keywordSuggestions: [Suggestion] = [
        "break", "case", "chan", "const", "continue", "default", "defer", "else",
        "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
        "map", "package", "range", "return", "select", "struct", "switch", "type", "var",
    ].map { Suggestion(label: $0, insertText: $0, detail: "Go keyword") }

    private static let predeclaredTypeSuggestions: [Suggestion] = [
        "any", "bool", "byte", "comparable", "complex64", "complex128", "error",
        "float32", "float64", "int", "int8", "int16", "int32", "int64",
        "rune", "string", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr",
    ].map { Suggestion(label: $0, insertText: $0, detail: "Go predeclared type") }

    private static let snippetSuggestions: [Suggestion] = [
        Suggestion(label: "package main", insertText: "package main\n", detail: "Go package declaration"),
        Suggestion(label: "import", insertText: "import (\n\t\n)", detail: "Go import block"),
        Suggestion(label: "func main", insertText: "func main() {\n\t\n}", detail: "Go main function"),
        Suggestion(label: "if err != nil", insertText: "if err != nil {\n\treturn err\n}", detail: "Go error guard"),
    ]

    private static func hasPrefix(_ value: String, _ prefix: String) -> Bool {
        value.range(
            of: prefix,
            options: [.anchored, .caseInsensitive, .diacriticInsensitive],
            locale: .current
        ) != nil
    }
}

public struct GoInlayHintPipeline: Equatable, Sendable {
    public var enableParameterNames: Bool
    public var enableAssignVariableTypes: Bool
    public var enableCompositeLiteralFields: Bool
    public var enableCompositeLiteralTypes: Bool
    public var enableConstantValues: Bool
    public var enableFunctionTypeParameters: Bool
    public var enableRangeVariableTypes: Bool

    public init(
        enableParameterNames: Bool = true,
        enableAssignVariableTypes: Bool = true,
        enableCompositeLiteralFields: Bool = true,
        enableCompositeLiteralTypes: Bool = true,
        enableConstantValues: Bool = true,
        enableFunctionTypeParameters: Bool = true,
        enableRangeVariableTypes: Bool = true
    ) {
        self.enableParameterNames = enableParameterNames
        self.enableAssignVariableTypes = enableAssignVariableTypes
        self.enableCompositeLiteralFields = enableCompositeLiteralFields
        self.enableCompositeLiteralTypes = enableCompositeLiteralTypes
        self.enableConstantValues = enableConstantValues
        self.enableFunctionTypeParameters = enableFunctionTypeParameters
        self.enableRangeVariableTypes = enableRangeVariableTypes
    }

    public static let `default` = GoInlayHintPipeline()

    public var goplsSettings: [String: String] {
        [
            "gopls.hints.parameterNames": String(enableParameterNames),
            "gopls.hints.assignVariableTypes": String(enableAssignVariableTypes),
            "gopls.hints.compositeLiteralFields": String(enableCompositeLiteralFields),
            "gopls.hints.compositeLiteralTypes": String(enableCompositeLiteralTypes),
            "gopls.hints.constantValues": String(enableConstantValues),
            "gopls.hints.functionTypeParameters": String(enableFunctionTypeParameters),
            "gopls.hints.rangeVariableTypes": String(enableRangeVariableTypes),
        ]
    }

    public static func shouldRequestHints(languageId: String, isLargeFileMode: Bool, visibleLineCount: Int) -> Bool {
        languageId == "go" && !isLargeFileMode && visibleLineCount > 0
    }
}

public struct GoFormatOnSavePolicy: Equatable, Sendable {
    public let isEnabled: Bool
    public let formatter: Formatter

    public enum Formatter: String, Sendable {
        case lsp
        case gofumpt
        case gofmt
    }

    public init(isEnabled: Bool, formatter: Formatter) {
        self.isEnabled = isEnabled
        self.formatter = formatter
    }

    public static func resolve(languageId: String, editorFormatOnSave: Bool, env: GoEnvResolver.Snapshot) -> GoFormatOnSavePolicy {
        guard languageId == "go", editorFormatOnSave else {
            return GoFormatOnSavePolicy(isEnabled: false, formatter: .lsp)
        }
        if env.goplsPath != nil {
            return GoFormatOnSavePolicy(isEnabled: true, formatter: .lsp)
        }
        if env.gofumptPath != nil {
            return GoFormatOnSavePolicy(isEnabled: true, formatter: .gofumpt)
        }
        return GoFormatOnSavePolicy(isEnabled: env.goPath != nil, formatter: .gofmt)
    }
}

public struct GoCodeLensPipeline: Equatable, Sendable {
    public struct Lens: Equatable, Sendable {
        public let line: Int
        public let title: String
        public let commandId: String

        public init(line: Int, title: String, commandId: String) {
            self.line = line
            self.title = title
            self.commandId = commandId
        }
    }

    public static func lenses(in content: String, languageId: String) -> [Lens] {
        guard languageId == "go" else { return [] }
        return content.components(separatedBy: .newlines).enumerated().compactMap { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("func "), isTestFunction(trimmed) else { return nil }
            return Lens(line: index, title: "run test", commandId: "go.test")
        }
    }

    private static func isTestFunction(_ line: String) -> Bool {
        ["Test", "Benchmark", "Fuzz", "Example"].contains { prefix in
            line.range(
                of: #"^func\s+\#(prefix)[A-Z0-9_]\w*\s*\("#,
                options: .regularExpression
            ) != nil
        }
    }
}

public struct DelveAdapter: Sendable {
    public enum LaunchKind: Equatable, Sendable {
        case debugPackage
        case debugFile
        case testPackage
    }

    public struct LaunchConfiguration: Equatable, Sendable {
        public let kind: LaunchKind
        public let projectPath: String
        public let program: String?
        public let arguments: [String]
        public let environment: [String: String]
        public let listenAddress: String

        public init(kind: LaunchKind, projectPath: String, program: String?, arguments: [String], environment: [String: String], listenAddress: String) {
            self.kind = kind
            self.projectPath = projectPath
            self.program = program
            self.arguments = arguments
            self.environment = environment
            self.listenAddress = listenAddress
        }
    }

    public static let defaultListenAddress = "127.0.0.1:0"

    public static func defaultLaunch(
        fileURL: URL?,
        projectPath: String,
        env: GoEnvResolver.Snapshot = GoEnvResolver.resolveSnapshot()
    ) -> LaunchConfiguration {
        LaunchConfiguration(
            kind: fileURL == nil ? .debugPackage : .debugFile,
            projectPath: projectPath,
            program: fileURL?.path,
            arguments: [],
            environment: env.processEnvironment,
            listenAddress: defaultListenAddress
        )
    }

    public static func testLaunch(
        projectPath: String,
        env: GoEnvResolver.Snapshot = GoEnvResolver.resolveSnapshot()
    ) -> LaunchConfiguration {
        LaunchConfiguration(
            kind: .testPackage,
            projectPath: projectPath,
            program: nil,
            arguments: [],
            environment: env.processEnvironment,
            listenAddress: defaultListenAddress
        )
    }

    public static func commandLine(
        for config: LaunchConfiguration,
        dlvPath: String? = GoEnvResolver.dlvPath
    ) -> (executable: String, arguments: [String])? {
        guard let dlvPath else { return nil }
        var arguments = [
            dapCommand(for: config.kind),
            "--headless",
            "--listen=\(config.listenAddress)",
            "--api-version=2",
        ]
        arguments.append(config.program ?? "./...")
        if !config.arguments.isEmpty {
            arguments.append("--")
            arguments.append(contentsOf: config.arguments)
        }
        return (dlvPath, arguments)
    }

    private static func dapCommand(for kind: LaunchKind) -> String {
        switch kind {
        case .debugPackage, .debugFile:
            "debug"
        case .testPackage:
            "test"
        }
    }
}
