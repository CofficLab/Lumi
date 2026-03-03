import Foundation

struct ListDirectoryTool: AgentTool {
    let name = "ls"
    let description = "List files and directories at a given path. Useful for exploring the project structure."
    
    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The absolute path to the directory to list"
                ],
                "recursive": [
                    "type": "boolean",
                    "description": "Whether to list subdirectories recursively (default: false)"
                ]
            ],
            "required": ["path"]
        ]
    }
    
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            throw NSError(domain: "ListDirectoryTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"])
        }

        let recursive = arguments["recursive"]?.value as? Bool ?? false
        let fileManager = FileManager.default
        
        var result = ""
        let rootURL = URL(fileURLWithPath: path)
        
        guard fileManager.fileExists(atPath: path) else {
            return "Error: Path does not exist."
        }
        
        do {
            if recursive {
                // Use contentsOfDirectory(at:includingPropertiesForKeys:options:) to avoid NSDirectoryEnumerator async issues
                // We'll use a manual breadth-first search or just the standard enumerator but collect into an array first?
                // Actually, FileManager.enumerator is not safe in async context if not careful.
                // Let's use a simpler recursive function or iterative stack approach with contentsOfDirectory.
                
                var result = ""
                var stack = [rootURL]
                var count = 0
                
                while !stack.isEmpty {
                    if count > 500 {
                        result += "... (Too many files, stopping list)\n"
                        break
                    }
                    
                    let currentURL = stack.removeFirst()
                    
                    // Skip hidden
                    if currentURL.lastPathComponent.hasPrefix(".") && currentURL != rootURL { continue }
                    
                    // Add to result (if not root)
                    if currentURL != rootURL {
                        let relativePath = currentURL.path.replacingOccurrences(of: path, with: "")
                        let isDir = (try? currentURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                        
                        // Clean up leading slash if present
                        let cleanPath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
                        result += "\(cleanPath)\(isDir ? "/" : "")\n"
                        count += 1
                    }
                    
                    // If directory, add children to stack
                    let isDir = (try? currentURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    if isDir {
                        let contents = try fileManager.contentsOfDirectory(at: currentURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                        stack.append(contentsOf: contents)
                    }
                }
                
                return result.isEmpty ? "(Empty directory)" : result
            } else {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                for item in contents {
                    if item.hasPrefix(".") { continue } // Skip hidden
                    let fullPath = (path as NSString).appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)
                    result += "\(item)\(isDir.boolValue ? "/" : "")\n"
                }
                return result.isEmpty ? "(Empty directory)" : result
            }
        } catch {
            return "Error listing directory: \(error.localizedDescription)"
        }
    }
}
