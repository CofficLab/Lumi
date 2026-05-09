import Foundation

public enum BrewError: Error, Sendable, Equatable {
    case notInstalled
    case commandFailed(String)
    case parsingError(Error)
    case notFound

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
        default:
            return false
        }
    }
}

public actor BrewService {
    public static let shared = BrewService()

    private final class LockedDataBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func append(_ chunk: Data) {
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }

        func snapshot() -> Data {
            lock.lock()
            let copy = data
            lock.unlock()
            return copy
        }
    }

    private var brewPath: String?

    public init() {
        self.brewPath = BrewService.findBrewPathStatic()
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
                name: f.name,
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
                installedVersion: version,
                outdated: false,
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

        let info = try JSONDecoder().decode(BrewInfo.self, from: data)
        var packages: [BrewPackage] = []

        for f in info.formulae {
            packages.append(BrewPackage(
                name: f.name,
                desc: f.desc,
                homepage: f.homepage,
                version: f.versions?.stable ?? "unknown",
                installedVersion: f.installed?.first?.version,
                outdated: true,
                isCask: false
            ))
        }

        for c in info.casks {
            packages.append(BrewPackage(
                name: c.token ?? c.name,
                desc: c.desc,
                homepage: c.homepage,
                version: c.version ?? "unknown",
                installedVersion: nil,
                outdated: true,
                isCask: true
            ))
        }

        return packages
    }

    public func search(query: String) async throws -> [BrewPackage] {
        let output = try await execute(["search", "--cask", query])
        let names = output.split(separator: "\n").map { String($0) }

        if names.isEmpty { return [] }

        let limitNames = Array(names.prefix(10))
        return try await getInfo(names: limitNames, isCask: true)
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
                    installedVersion: nil,
                    outdated: false,
                    isCask: true
                ))
            }
        } else {
            for f in info.formulae {
                packages.append(BrewPackage(
                    name: f.name,
                    desc: f.desc,
                    homepage: f.homepage,
                    version: f.versions?.stable ?? "unknown",
                    installedVersion: f.installed?.first?.version,
                    outdated: false,
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

        let task = Process()
        task.executableURL = URL(fileURLWithPath: brewPath)
        task.arguments = args

        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
        if let path = env["PATH"] {
            env["PATH"] = path + ":/opt/homebrew/bin:/usr/local/bin"
        } else {
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        }
        task.environment = env

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        let buffer = LockedDataBuffer()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { h in
            let chunk = h.availableData
            if !chunk.isEmpty { buffer.append(chunk) }
        }

        do {
            try task.run()
        } catch {
            handle.readabilityHandler = nil
            throw error
        }

        await withCheckedContinuation { continuation in
            task.terminationHandler = { _ in
                continuation.resume()
            }
        }

        handle.readabilityHandler = nil
        let final = handle.availableData
        if !final.isEmpty { buffer.append(final) }

        let output = String(data: buffer.snapshot(), encoding: .utf8) ?? ""
        if task.terminationStatus == 0 {
            return output
        } else {
            throw BrewError.commandFailed(output)
        }
    }
}