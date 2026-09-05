import Foundation

struct GitDirectorySnapshot: Equatable, Sendable {
    let head: String?
    let index: String?
    let stash: String?
    let refs: String?
}

enum GitDirectoryResolver {
    enum ResolverError: Error, Equatable, Sendable {
        case gitDirectoryNotFound(String)
        case invalidGitFile(String)
    }

    static func resolveGitDirectory(for projectURL: URL) throws -> URL {
        let dotGitURL = projectURL.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dotGitURL.path, isDirectory: &isDirectory) else {
            throw ResolverError.gitDirectoryNotFound(dotGitURL.path)
        }
        if isDirectory.boolValue { return dotGitURL }

        let content = try String(contentsOf: dotGitURL, encoding: .utf8)
        guard let line = content.split(separator: "\n").first(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("gitdir:")
        }) else {
            throw ResolverError.invalidGitFile(dotGitURL.path)
        }
        let rawPath = line
            .replacingOccurrences(of: "gitdir:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if rawPath.hasPrefix("/") {
            return URL(fileURLWithPath: rawPath, isDirectory: true)
        }
        return projectURL.appendingPathComponent(rawPath).standardizedFileURL
    }

    static func readSnapshot(gitDirectory: URL) -> GitDirectorySnapshot {
        GitDirectorySnapshot(
            head: readHeadHash(gitDirectory: gitDirectory),
            index: fileContentFingerprint(gitDirectory.appendingPathComponent("index")),
            stash: stashFingerprint(gitDirectory: gitDirectory),
            refs: refsFingerprint(gitDirectory: gitDirectory)
        )
    }

    static func readHeadHash(gitDirectory: URL) -> String? {
        let headURL = gitDirectory.appendingPathComponent("HEAD")
        guard let content = try? String(contentsOf: headURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            return nil
        }
        guard content.hasPrefix("ref:") else { return content }

        let refPath = content
            .replacingOccurrences(of: "ref:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let refURL = gitDirectory.appendingPathComponent(refPath)
        if let refHash = try? String(contentsOf: refURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !refHash.isEmpty {
            return refHash
        }
        return readPackedRef(gitDirectory: gitDirectory, refPath: refPath)
    }

    static func fileContentFingerprint(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "\(data.count):\(String(hash, radix: 16))"
    }

    private static func stashFingerprint(gitDirectory: URL) -> String? {
        let refs = fileContentFingerprint(gitDirectory.appendingPathComponent("refs/stash"))
        let logs = fileContentFingerprint(gitDirectory.appendingPathComponent("logs/refs/stash"))
        switch (refs, logs) {
        case (nil, nil): return nil
        case let (value?, nil), let (nil, value?): return value
        case let (refs?, logs?): return "\(refs):\(logs)"
        }
    }

    private static func refsFingerprint(gitDirectory: URL) -> String? {
        let values = [
            directoryContentFingerprint(gitDirectory.appendingPathComponent("refs/heads")),
            directoryContentFingerprint(gitDirectory.appendingPathComponent("refs/remotes")),
            directoryContentFingerprint(gitDirectory.appendingPathComponent("refs/tags")),
            fileContentFingerprint(gitDirectory.appendingPathComponent("packed-refs")),
        ].compactMap { $0 }
        return values.isEmpty ? nil : values.joined(separator: "|")
    }

    private static func directoryContentFingerprint(_ url: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var entries: [String] = []
        for case let fileURL as URL in enumerator {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  let fingerprint = fileContentFingerprint(fileURL) else { continue }
            let relativePath = String(fileURL.path.dropFirst(url.path.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            entries.append("\(relativePath)=\(fingerprint)")
        }
        return entries.isEmpty ? nil : entries.sorted().joined(separator: ";")
    }

    private static func readPackedRef(gitDirectory: URL, refPath: String) -> String? {
        guard let content = try? String(
            contentsOf: gitDirectory.appendingPathComponent("packed-refs"),
            encoding: .utf8
        ) else { return nil }
        for line in content.split(separator: "\n") where !line.hasPrefix("#") && !line.hasPrefix("^") {
            let parts = line.split(separator: " ")
            if parts.count == 2, parts[1] == refPath { return String(parts[0]) }
        }
        return nil
    }
}
