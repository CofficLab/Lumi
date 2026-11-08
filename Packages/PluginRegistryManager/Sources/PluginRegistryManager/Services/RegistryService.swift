import Foundation

public actor RegistryService {
    public static let shared = RegistryService()

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
    
    private func execute(_ command: String) async throws -> String {
        let task = Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            // 确定性回收管道 fd：不能依赖 autorelease pool，否则每次调用泄漏 4 个
            // fd，长时间运行后耗尽进程上限（EMFILE）。
            defer {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                try? stdoutPipe.fileHandleForReading.close()
                try? stdoutPipe.fileHandleForWriting.close()
                try? stderrPipe.fileHandleForReading.close()
                try? stderrPipe.fileHandleForWriting.close()
            }
            
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // Use -l to load user profile/rc files to ensure PATH is correct
            process.arguments = ["-l", "-c", command]
            
            // Explicitly add common paths to environment
            var env = ProcessInfo.processInfo.environment
            let commonPaths = [
                "/opt/homebrew/bin",
                "/usr/local/bin",
                "/usr/bin",
                "/bin",
                "/usr/sbin",
                "/sbin",
                "\(FileManager.default.homeDirectoryForCurrentUser.path)/.cargo/bin", // Rust
                "\(FileManager.default.homeDirectoryForCurrentUser.path)/go/bin" // Go
            ]
            let existingPath = env["PATH"] ?? ""
            env["PATH"] = commonPaths.joined(separator: ":") + ":" + existingPath
            process.environment = env
            
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            try process.run()
            
            let stdoutBuffer = LockedDataBuffer()
            let stderrBuffer = LockedDataBuffer()
            let stdoutHandle = stdoutPipe.fileHandleForReading
            let stderrHandle = stderrPipe.fileHandleForReading

            stdoutHandle.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty { stdoutBuffer.append(chunk) }
            }
            stderrHandle.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty { stderrBuffer.append(chunk) }
            }

            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }

            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil

            let finalStdout = stdoutHandle.availableData
            if !finalStdout.isEmpty { stdoutBuffer.append(finalStdout) }
            let finalStderr = stderrHandle.availableData
            if !finalStderr.isEmpty { stderrBuffer.append(finalStderr) }
            
            let output = String(data: stdoutBuffer.snapshot(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let error = String(data: stderrBuffer.snapshot(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Some commands output to stderr even on success, or non-zero exit code means something else.
            // But generally check terminationStatus.
            if process.terminationStatus != 0 {
                // Ignore "key not found" errors for get commands
                if output.isEmpty && !error.isEmpty {
                    throw NSError(domain: "RegistryService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: error])
                }
            }
            
            return output
        }
        return try await task.value
    }
    
    public func getCurrentRegistry(for type: RegistryType) async throws -> String {
        do {
            switch type {
            case .npm:
                return try await execute("npm config get registry")
            case .yarn:
                return try await execute("yarn config get registry")
            case .pnpm:
                return try await execute("pnpm config get registry")
            case .docker:
                return try await getDockerRegistry()
            case .pip:
                // pip config list returns all configs.
                // pip config get global.index-url might fail if not set.
                let output = try await execute("pip config get global.index-url")
                return output.isEmpty ? "Default (PyPI)" : output
            case .go:
                return try await execute("go env GOPROXY")
            }
        } catch {
            // Return default or specific error message
            // If tool is not installed, it will throw.
            if error.localizedDescription.contains("command not found") {
                return "Not Installed"
            }
            return "Default/Unknown"
        }
    }
    
    public func setRegistry(for type: RegistryType, url: String) async throws {
        switch type {
        case .npm:
            _ = try await execute("npm config set registry \(url)")
        case .yarn:
            _ = try await execute("yarn config set registry \(url)")
        case .pnpm:
            _ = try await execute("pnpm config set registry \(url)")
        case .docker:
            try await setDockerRegistry(url: url)
        case .pip:
            _ = try await execute("pip config set global.index-url \(url)")
        case .go:
            _ = try await execute("go env -w GOPROXY=\(url)")
        }
    }
    
    private func getDockerRegistry() async throws -> String {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".docker/daemon.json")
        guard let data = try? Data(contentsOf: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mirrors = json["registry-mirrors"] as? [String],
              let first = mirrors.first else {
            return "Default"
        }
        return first
    }
    
    private func setDockerRegistry(url: String) async throws {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".docker/daemon.json")

        // 文件已存在却读不出来时必须中止：不能拿空配置覆盖用户原有设置。
        var existing: Data?
        if FileManager.default.fileExists(atPath: path.path) {
            do {
                existing = try Data(contentsOf: path)
            } catch {
                throw RegistryServiceError.dockerDaemonConfigUnreadable(error.localizedDescription)
            }
        }

        let data = try DockerDaemonConfig.mergedData(existing: existing, mirrorURL: url)

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: path, options: .atomic)
    }
}

/// Docker 镜像源写入：合并到现有 daemon.json，解析失败直接抛错。
enum DockerDaemonConfig {
    /// 把 `registry-mirrors` 合并进现有配置；`existing` 为 nil 表示文件不存在。
    /// 现有内容无法解析时抛 `dockerDaemonConfigUnreadable`，调用方不会写文件。
    static func mergedData(existing: Data?, mirrorURL: String) throws -> Data {
        var json: [String: Any] = [:]

        if let existing {
            let object: Any
            do {
                object = try JSONSerialization.jsonObject(with: existing)
            } catch {
                throw RegistryServiceError.dockerDaemonConfigUnreadable(error.localizedDescription)
            }
            guard let dictionary = object as? [String: Any] else {
                throw RegistryServiceError.dockerDaemonConfigUnreadable("root value is not a JSON object")
            }
            json = dictionary
        }

        json["registry-mirrors"] = [mirrorURL]

        do {
            return try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        } catch {
            throw RegistryServiceError.dockerDaemonConfigUnreadable(error.localizedDescription)
        }
    }
}

public enum RegistryServiceError: LocalizedError, Equatable {
    /// 现有 daemon.json 无法读取或解析，未做任何写入。
    case dockerDaemonConfigUnreadable(String)

    public var errorDescription: String? {
        switch self {
        case .dockerDaemonConfigUnreadable(let detail):
            return "daemon.json could not be read or parsed, so the Docker registry was not changed. Fix the file and try again. (\(detail))"
        }
    }
}
