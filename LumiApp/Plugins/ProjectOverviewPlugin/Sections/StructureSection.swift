import Foundation

enum StructureSection {
    private static let maxRootItems = 25
    private static let maxChildrenPerDir = 30

    static func render(at root: URL) -> String {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return "(Unable to list directory)"
        }
        let sorted = contents.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        var lines: [String] = []
        var rootCount = 0
        for url in sorted {
            guard rootCount < maxRootItems else {
                lines.append("... (more items omitted)")
                break
            }
            let name = url.lastPathComponent
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            lines.append(name + (isDir ? "/" : ""))
            rootCount += 1
            if isDir {
                guard let children = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
                let sortedChildren = children.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                let limited = sortedChildren.prefix(maxChildrenPerDir)
                for child in limited {
                    let cName = child.lastPathComponent
                    let cIsDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    lines.append("  \(cName)\(cIsDir ? "/" : "")")
                }
                if sortedChildren.count > maxChildrenPerDir {
                    lines.append("  ... (\(sortedChildren.count - maxChildrenPerDir) more)")
                }
            }
        }
        return lines.isEmpty ? "(Empty)" : lines.joined(separator: "\n")
    }
}
