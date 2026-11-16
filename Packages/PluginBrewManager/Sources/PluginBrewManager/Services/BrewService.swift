import Foundation
import KitShell

public enum BrewError: Error, Sendable, Equatable, LocalizedError {
    case notInstalled
    case commandFailed(String)
    case parsingError(Error)
    case notFound
    case outputTruncated

    public var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Homebrew is not installed or could not be located."
        case .commandFailed(let detail):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "The brew command failed." : trimmed
        case .parsingError(let error):
            return "Failed to parse Homebrew output: \(error.localizedDescription)"
        case .notFound:
            return "The requested package was not found."
        case .outputTruncated:
            return "Homebrew output was truncated and is incomplete."
        }
    }

    public static func == (lhs: BrewError, rhs: BrewError) -> Bool {
        switch (lhs, rhs) {
        case (.notInstalled, .notInstalled):
            return true
        case (.commandFailed(let l), .commandFailed(let r)):
            return l == r
        case (.parsingError, .parsingError):
            // Error 不是 Equatable，只比较 case 类型
            return true
        case (.notFound, .notFound):
            return true
        case (.outputTruncated, .outputTruncated):
            return true
        default:
            return false
        }
    }
}

public actor BrewService {
    public static let shared = BrewService()

    private var brewPath: String?
    private let commandRunner: BrewCommandRunner

    /// brew 的 JSON 输出（如 info --json=v2 --installed）可能远超 KitShell 默认的
    /// 64 KiB；上限提到 16 MiB 容纳完整文档，仍被截断时由 execute 报错（#408）。
    static let maxOutputBytes = 16 * 1024 * 1024

    public init() {
        self.brewPath = BrewService.findBrewPathStatic()
        self.commandRunner = { executable, arguments, environment in
            try await BrewService.runBrewCommand(
                executable: executable,
                arguments: arguments,
                environment: environment
            )
        }
    }

    init(
        brewPath: String?,
        commandRunner: @escaping BrewCommandRunner
    ) {
        self.brewPath = brewPath
        self.commandRunner = commandRunner
    }

    private static func findBrewPathStatic() -> String? {
        let possiblePaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    public func checkInstalled() -> Bool {
        return brewPath != nil
    }

    public func getVersion() async throws -> String {
        return try await execute(["--version"])
    }

    // MARK: - Core Operations

    public func listInstalled() async throws -> [BrewPackage] {
        let jsonString = try await execute(["info", "--json=v2", "--installed"])
        guard let data = jsonString.data(using: .utf8) else {
            throw BrewError.parsingError(NSError(domain: "BrewService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid data"]))
        }

        let info = try JSONDecoder().decode(BrewInfo.self, from: data)
        var packages: [BrewPackage] = []

        for f in info.formulae {
            let version = f.versions?.stable ?? "unknown"
            let installedVer = f.installed?.first?.version
            packages.append(BrewPackage(
                name: f.full_name ?? f.name,
                desc: f.desc,
                homepage: f.homepage,
                version: version,
                installedVersion: installedVer,
                outdated: f.outdated ?? false,
                isCask: false
            ))
        }

        for c in info.casks {
            let version = c.version ?? "unknown"
            packages.append(BrewPackage(
                name: c.token ?? c.name,
                desc: c.desc,
                homepage: c.homepage,
                version: version,
                installedVersion: c.installed?.first?.version,
                outdated: c.outdated ?? false,
                isCask: true
            ))
        }

        return packages
    }

    public func getOutdated() async throws -> [BrewPackage] {
        let jsonString = try await execute(["outdated", "--json=v2"])
        guard let data = jsonString.data(using: .utf8) else {
            throw BrewError.parsingError(NSError(domain: "BrewService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid data"]))
        }

        // outdated 的 schema 与 info 不同：目标版本在 current_version、已装版本在
        // installed_versions（数组），name 对 Tap formula 已含 tap、对 cask 即 token。
        // 用 BrewInfo 解码会读不到 versions/version，目标版本全部退化成 "unknown"（#847）。
        let outdated = try JSONDecoder().decode(BrewOutdated.self, from: data)
        var packages: [BrewPackage] = []

        for f in outdated.formulae {
            packages.append(BrewPackage(
                name: f.name,
                desc: nil,
                homepage: nil,
                version: f.current_version,
                installedVersion: f.installed_versions.first,
                outdated: true,
                isCask: false
            ))
        }

        for c in outdated.casks {
            packages.append(BrewPackage(
                name: c.name,
                desc: nil,
                homepage: nil,
                version: c.current_version,
                installedVersion: c.installed_versions.first,
                outdated: true,
                isCask: true
            ))
        }

        return packages
    }

    public func search(query: String) async throws -> [BrewPackage] {
        let formulaNames = try await searchNames(["search", "--formula", query])
        let caskNames = try await searchNames(["search", "--cask", query])

        // 每类各自限额；共享配额会在 Formula 满 10 个时把 Cask 配额挤成 0，整类应用被丢弃。
        let formulaLimit = Array(formulaNames.prefix(10))
        let caskLimit = Array(caskNames.prefix(10))

        async let formulaInfo = getInfo(names: formulaLimit, isCask: false)
        async let caskInfo = getInfo(names: caskLimit, isCask: true)

        return try await formulaInfo + caskInfo
    }

    public func getInfo(names: [String], isCask: Bool) async throws -> [BrewPackage] {
        if names.isEmpty { return [] }

        var args = ["info", "--json=v2"]
        if isCask {
            args.append("--cask")
        }
        args.append(contentsOf: names)

        let jsonString = try await execute(args)
        guard let data = jsonString.data(using: .utf8) else { return [] }

        let info = try JSONDecoder().decode(BrewInfo.self, from: data)
        var packages: [BrewPackage] = []

        if isCask {
            for c in info.casks {
                packages.append(BrewPackage(
                    name: c.token ?? c.name,
                    desc: c.desc,
                    homepage: c.homepage,
                    version: c.version ?? "unknown",
                    installedVersion: c.installed?.first?.version,
                    outdated: c.outdated ?? false,
                    isCask: true
                ))
            }
        } else {
            for f in info.formulae {
                packages.append(BrewPackage(
                    name: f.full_name ?? f.name,
                    desc: f.desc,
                    homepage: f.homepage,
                    version: f.versions?.stable ?? "unknown",
                    installedVersion: f.installed?.first?.version,
                    outdated: f.outdated ?? false,
                    isCask: false
                ))
            }
        }

        return packages
    }

    // MARK: - Actions

    public func install(name: String, isCask: Bool) async throws {
        var args = ["install"]
        if isCask {
            args.append("--cask")
        }
        args.append(name)
        _ = try await execute(args)
    }

    public func uninstall(name: String, isCask: Bool) async throws {
        var args = ["uninstall"]
        if isCask {
            args.append("--cask")
        }
        args.append(name)
        _ = try await execute(args)
    }

    public func upgrade(name: String, isCask: Bool) async throws {
        var args = ["upgrade"]
        if isCask {
            args.append("--cask")
        }
        args.append(name)
        _ = try await execute(args)
    }

    // MARK: - Private Execution

    private func execute(_ args: [String]) async throws -> String {
        guard let brewPath = brewPath else {
            throw BrewError.notInstalled
        }

        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let result = try await commandRunner(
            brewPath,
            args,
            [
                "HOMEBREW_NO_AUTO_UPDATE": "1",
                "HOMEBREW_NO_INSTALL_CLEANUP": "1",
                "PATH": currentPath + ":/opt/homebrew/bin:/usr/local/bin"
            ]
        )

        if result.exitCode == 0 {
            // 截断后只剩尾部，绝不是完整 JSON；宁可报错也不能当成功解析（#408）。
            if result.stdoutTruncated {
                throw BrewError.outputTruncated
            }
            return result.stdout
        }
        throw BrewError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
    }

    private func searchNames(_ args: [String]) async throws -> [String] {
        let output = try await execute(args)
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func runBrewCommand(
        executable: String,
        arguments: [String],
        environment: [String: String]
    ) async throws -> BrewCommandResult {
        let result = try await Shell.execute(
            executable: executable,
            arguments: arguments,
            options: ShellOptions(
                environment: environment,
                throwsOnError: false,
                maxOutputBytes: maxOutputBytes
            )
        )
        return BrewCommandResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            stdoutTruncated: result.stdoutTruncated
        )
    }
}

struct BrewCommandResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let stdoutTruncated: Bool

    init(exitCode: Int32, stdout: String, stderr: String, stdoutTruncated: Bool = false) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.stdoutTruncated = stdoutTruncated
    }
}

typealias BrewCommandRunner = @Sendable (
    _ executable: String,
    _ arguments: [String],
    _ environment: [String: String]
) async throws -> BrewCommandResult
