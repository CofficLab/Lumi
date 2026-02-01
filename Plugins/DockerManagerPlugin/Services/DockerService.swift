import Foundation

enum DockerError: Error, LocalizedError {
    case commandFailed(String)
    case parsingFailed(String)
    case dockerNotFound
    
    var errorDescription: String? {
        switch self {
        case .commandFailed(let msg): return "Docker command failed: \(msg)"
        case .parsingFailed(let msg): return "Failed to parse Docker output: \(msg)"
        case .dockerNotFound: return "Docker executable not found. Please ensure Docker is installed and in your PATH."
        }
    }
}

actor DockerService {
    static let shared = DockerService()
    
    private var dockerPath: String?
    
    init() {
        // Attempt to find docker path
        let commonPaths = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", "/usr/bin/docker"]
        var foundPath: String?
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                foundPath = path
                break
            }
        }
        self.dockerPath = foundPath
    }
    
    private func runDockerCommand(_ args: [String]) async throws -> String {
        guard let dockerPath = dockerPath else {
            throw DockerError.dockerNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: dockerPath)
        process.arguments = args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus == 0 {
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } else {
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: DockerError.commandFailed(errorMsg))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Image Operations
    
    func listImages() async throws -> [DockerImage] {
        // Format: JSON Lines
        // We use --format '{{json .}}' to get JSON objects, but Docker outputs one JSON object per line, not a JSON array.
        let output = try await runDockerCommand(["images", "--format", "{{json .}}"])
        
        var images: [DockerImage] = []
        let lines = output.components(separatedBy: .newlines)
        
        let decoder = JSONDecoder()
        
        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8) {
                do {
                    let image = try decoder.decode(DockerImage.self, from: data)
                    images.append(image)
                } catch {
                    print("Failed to decode image line: \(error)")
                }
            }
        }
        
        return images
    }
    
    func removeImage(_ id: String, force: Bool = false) async throws {
        var args = ["rmi"]
        if force { args.append("-f") }
        args.append(id)
        _ = try await runDockerCommand(args)
    }
    
    func pullImage(_ name: String) async throws -> String {
        // This might take a while, maybe we should support streaming output in a real production app.
        // For now, we wait for completion.
        return try await runDockerCommand(["pull", name])
    }
    
    func inspectImage(_ id: String) async throws -> DockerInspect {
        let output = try await runDockerCommand(["inspect", id])
        guard let data = output.data(using: .utf8) else {
            throw DockerError.parsingFailed("Invalid UTF-8 output")
        }
        
        let decoder = JSONDecoder()
        // inspect returns an array of objects
        let results = try decoder.decode([DockerInspect].self, from: data)
        guard let first = results.first else {
            throw DockerError.parsingFailed("No inspect data returned")
        }
        return first
    }
    
    func getImageHistory(_ id: String) async throws -> [DockerImageHistory] {
        // history --format '{{json .}}'
        let output = try await runDockerCommand(["history", "--format", "{{json .}}", "--no-trunc", id])
        
        var history: [DockerImageHistory] = []
        let lines = output.components(separatedBy: .newlines)
        let decoder = JSONDecoder()
        
        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8) {
                do {
                    let item = try decoder.decode(DockerImageHistory.self, from: data)
                    history.append(item)
                } catch {
                    print("Failed to decode history line: \(error)")
                }
            }
        }
        
        return history
    }
    
    func tagImage(_ id: String, target: String) async throws {
        _ = try await runDockerCommand(["tag", id, target])
    }
    
    func exportImage(_ id: String, to path: String) async throws {
        _ = try await runDockerCommand(["save", "-o", path, id])
    }
    
    func loadImage(from path: String) async throws {
        _ = try await runDockerCommand(["load", "-i", path])
    }
    
    func scanImage(_ id: String) async throws -> String {
        // Try to find trivy
        let commonTrivyPaths = ["/usr/local/bin/trivy", "/opt/homebrew/bin/trivy"]
        var trivyPath: String?
        for path in commonTrivyPaths {
            if FileManager.default.fileExists(atPath: path) {
                trivyPath = path
                break
            }
        }
        
        guard let trivy = trivyPath else {
            throw DockerError.commandFailed("Trivy security scanner not found. Please install trivy (brew install trivy).")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: trivy)
        process.arguments = ["image", "--format", "table", id]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Scan failed"
                    continuation.resume(throwing: DockerError.commandFailed(errorMsg))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
