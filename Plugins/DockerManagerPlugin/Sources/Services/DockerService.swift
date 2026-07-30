import Foundation
import os
import SuperLogKit
import ShellKit

/// The primary namespace for DockerKit
public enum DockerKit: SuperLog {
    /// Logger instance for DockerKit operations
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.docker")
    /// 是否启用日志输出
    nonisolated(unsafe) public static var verbose: Bool = true
}

/// Core service for Docker operations
public actor DockerService: SuperLog {
    public static let shared = DockerService()

    private var dockerPath: String?
    
    public init() {
        self.dockerPath = Self.findDockerPath()
    }
    
    private static func findDockerPath() -> String? {
        let commonPaths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker", 
            "/usr/bin/docker"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    /// Execute a Docker command with error handling
    private func runDockerCommand(_ args: [String]) async throws -> String {
        guard let dockerPath = dockerPath else {
            throw DockerError.dockerNotFound
        }

        let result = try await Shell.execute(
            executable: dockerPath,
            arguments: args,
            options: ShellOptions(throwsOnError: false)
        )
        if result.exitCode == 0 {
            return result.stdout
        }
        throw DockerError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
    }
    
    // MARK: - Image Operations
    
    /// List all Docker images
    /// - Returns: Array of DockerImage objects sorted by creation time
    /// - Throws: DockerError.commandFailed if docker command fails
    public func listImages() async throws -> [DockerImage] {
        let output = try await runDockerCommand(["images", "--format", "{{json .}}"])
        let lines = output.components(separatedBy: .newlines)
        
        var images: [DockerImage] = []
        let decoder = JSONDecoder()
        
        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8) {
                do {
                    let image = try decoder.decode(DockerImage.self, from: data)
                    images.append(image)
                } catch {
                    if DockerKit.verbose {
                                            DockerKit.logger.error("\(self.t)Failed to decode image line: \(error)")
                    }
                }
            }
        }
        
        return images
    }
    
    /// Remove a Docker image
    /// - Parameters:
    ///   - id: Image ID or ID:tag
    ///   - force: Whether to force remove the image
    public func removeImage(_ id: String, force: Bool = false) async throws {
        var args = ["rmi"]
        if force { args.append("-f") }
        args.append(id)
        _ = try await runDockerCommand(args)
    }
    
    /// Pull a Docker image
    /// - Parameter name: Image name (e.g., "ubuntu:20.04")
    /// - Returns: Docker output from the pull command
    public func pullImage(_ name: String) async throws -> String {
        return try await runDockerCommand(["pull", name])
    }
    
    /// Get detailed information about a Docker image
    /// - Parameter id: Image ID
    /// - Returns: DockerInspect object
    public func inspectImage(_ id: String) async throws -> DockerInspect {
        let output = try await runDockerCommand(["inspect", id])
        
        guard let data = output.data(using: .utf8) else {
            throw DockerError.parsingFailed("Invalid UTF-8 output")
        }
        
        let decoder = JSONDecoder()
        let results: [DockerInspect] = try decoder.decode([DockerInspect].self, from: data)
        guard let first = results.first else {
            throw DockerError.parsingFailed("No inspect data returned")
        }
        return first
    }
    
    /// Get image history
    /// - Parameter id: Image ID
    /// - Returns: Array of DockerImageHistory objects
    public func getImageHistory(_ id: String) async throws -> [DockerImageHistory] {
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
                    if DockerKit.verbose {
                                            DockerKit.logger.error("\(self.t)Failed to decode history line: \(error)")
                    }
                }
            }
        }
        
        return history
    }
    
    /// Tag an image
    /// - Parameters:
    ///   - id: Source image ID
    ///   - target: Target name in format "repository:tag"
    public func tagImage(_ id: String, target: String) async throws {
        _ = try await runDockerCommand(["tag", id, target])
    }
    
    /// Export image to tar archive
    /// - Parameters:
    ///   - id: Image ID
    ///   - path: Output file path
    public func exportImage(_ id: String, to path: String) async throws {
        _ = try await runDockerCommand(["save", "-o", path, id])
    }
    
    /// Load image from tar archive
    /// - Parameter path: Path to tar file
    public func loadImage(from path: String) async throws {
        _ = try await runDockerCommand(["load", "-i", path])
    }
    
    /// Scan image for security vulnerabilities
    /// - Parameter id: Image ID to scan
    /// - Returns: Security scan output string
    public func scanImage(_ id: String) async throws -> String {
        let trivyPath = Self.findTrivyPath()
        guard let trivy = trivyPath else {
            throw DockerError.commandFailed("Trivy security scanner not found. Please install trivy (brew install trivy).")
        }
        
        let result = try await Shell.execute(
            executable: trivy,
            arguments: ["image", "--format", "table", id],
            options: ShellOptions(throwsOnError: false)
        )
        if result.exitCode == 0 {
            return result.stdout
        }
        throw DockerError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
    }
    
    // MARK: - Private Helpers
    
    private static func findTrivyPath() -> String? {
        let commonTrivyPaths = [
            "/usr/local/bin/trivy",
            "/opt/homebrew/bin/trivy"
        ]
        
        for path in commonTrivyPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
}

// MARK: - Supporting Types
