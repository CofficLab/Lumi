import Foundation

/// Disk cache for parsed Xcode workspace graphs.
public enum ProjectGraphCache {
    public static let fileName = "project-graph.json"

    public struct Snapshot: Codable, Equatable, Sendable {
        public var pbxprojHash: String?
        public var workspaceContext: XcodeWorkspaceContext

        public init(pbxprojHash: String?, workspaceContext: XcodeWorkspaceContext) {
            self.pbxprojHash = pbxprojHash
            self.workspaceContext = workspaceContext
        }
    }

    public static func url(in storeDirectory: URL) -> URL {
        storeDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    public static func load(from storeDirectory: URL, expectedHash: String?) -> XcodeWorkspaceContext? {
        let fileURL = url(in: storeDirectory)
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return nil
        }
        if let expectedHash, snapshot.pbxprojHash != expectedHash {
            return nil
        }
        return snapshot.workspaceContext
    }

    @discardableResult
    public static func save(
        _ workspaceContext: XcodeWorkspaceContext,
        pbxprojHash: String?,
        to storeDirectory: URL
    ) -> Bool {
        let snapshot = Snapshot(pbxprojHash: pbxprojHash, workspaceContext: workspaceContext)
        guard let data = try? JSONEncoder().encode(snapshot) else { return false }
        do {
            try data.write(to: url(in: storeDirectory), options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
