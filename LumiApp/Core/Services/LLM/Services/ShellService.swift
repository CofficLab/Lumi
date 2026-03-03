import Foundation
import Combine

@MainActor
class ShellService: ObservableObject {
    static let shared = ShellService()
    
    @Published var currentOutput: String = ""
    @Published var isRunning: Bool = false
    
    // Default to home directory
    var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    
    func execute(_ command: String) async throws -> String {
        isRunning = true
        defer { isRunning = false }
        
        // Capture currentDirectory on MainActor before entering detached task
        let workingDirectory = self.currentDirectory
        
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let pipe = Pipe()
            let errorPipe = Pipe()
            
            // Use zsh for shell execution
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            
            // Set current working directory
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            
            // Set environment
            var env = ProcessInfo.processInfo.environment
            env["TERM"] = "xterm-256color"
            env["LANG"] = "en_US.UTF-8"
            // Add Homebrew path
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = env
            
            process.standardOutput = pipe
            process.standardError = errorPipe
            
            try process.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            process.waitUntilExit()
            
            let output = String(data: data, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            let result = output + (errorOutput.isEmpty ? "" : "\nError:\n\(errorOutput)")
            
            // Update CWD if command was 'cd'
            if command.trimmingCharacters(in: .whitespaces).hasPrefix("cd ") {
                // This is tricky because the sub-process changes its own cwd, not the parent.
                // We need to handle 'cd' manually or parse the intent.
                // For now, let's assume we don't support persistent 'cd' via shell directly unless we track it.
                // A better way is to chain commands or update self.currentDirectory explicitly.
            }
            
            return result
        }.value
    }
    
    func updateWorkingDirectory(_ path: String) {
        var targetPath = path
        if path.hasPrefix("~") {
            targetPath = (path as NSString).expandingTildeInPath
        }
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir), isDir.boolValue {
            self.currentDirectory = targetPath
        }
    }
}
