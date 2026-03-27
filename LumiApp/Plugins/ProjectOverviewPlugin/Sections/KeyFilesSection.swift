import Foundation

enum KeyFilesSection {
    static func render(at root: URL) -> String {
        let fm = FileManager.default
        func exists(_ name: String) -> Bool {
            fm.fileExists(atPath: root.appendingPathComponent(name).path)
        }
        var lines: [String] = []
        if exists("README.md") { lines.append("- README: README.md") }
        else if exists("README") { lines.append("- README: README") }
        else { lines.append("- README: None") }
        lines.append(exists("LICENSE") ? "- LICENSE: LICENSE" : "- LICENSE: None")
        lines.append(exists(".gitignore") ? "- .gitignore: Yes" : "- .gitignore: No")
        return lines.joined(separator: "\n")
    }
}
