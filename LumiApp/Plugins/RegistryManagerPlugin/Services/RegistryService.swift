import Foundation

actor RegistryService {
    static let shared = RegistryService()
    
    private func execute(_ command: String) async throws -> String {
        let task = Task.detached(priority: .userInitiated) {
            let process = Process()
            let pipe = Pipe()
            let errorPipe = Pipe()
            
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
            
            process.standardOutput = pipe
            process.standardError = errorPipe
            
            try process.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            process.waitUntilExit()
            
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let error = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
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
    
    func getCurrentRegistry(for type: RegistryType) async throws -> String {
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
    
    func setRegistry(for type: RegistryType, url: String) async throws {
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
        var json: [String: Any] = [:]
        
        if let data = try? Data(contentsOf: path),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        json["registry-mirrors"] = [url]
        
        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        try data.write(to: path)
    }
}
