import Foundation

struct GitDirectorySnapshot: Equatable, Sendable {
    let head: String?
    /// HEAD 的符号引用（如 `refs/heads/main`）；detached 时为 nil。
    /// 同 commit 切换分支只改这里，hash 不变（#213）。
    let headRef: String?
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
        let projectDirectory = projectURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: projectDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ResolverError.gitDirectoryNotFound(
                projectDirectory.appendingPathComponent(".git").path
            )
        }

        // 与 git 一致向上查找 `.git`：把仓库子目录作为项目打开时，
        // 仓库根在上层目录（#913）。
        var candidate = projectDirectory
        for _ in 0..<128 {
            if let resolved = try resolveGitEntry(in: candidate) { return resolved }
            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else { break }
            candidate = parent
        }
        throw ResolverError.gitDirectoryNotFound(
            projectDirectory.appendingPathComponent(".git").path
        )
    }

    /// 只检查 `candidate/.git`：不存在返回 `nil` 继续向上；
    /// 存在但格式非法则立即抛错，不越过这个仓库边界。
    private static func resolveGitEntry(in candidate: URL) throws -> URL? {
        let dotGitURL = candidate.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dotGitURL.path, isDirectory: &isDirectory) else {
            return nil
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
        return candidate.appendingPathComponent(rawPath).standardizedFileURL
    }

    static func readSnapshot(gitDirectory: URL) -> GitDirectorySnapshot {
        GitDirectorySnapshot(
            head: readHeadHash(gitDirectory: gitDirectory),
            headRef: readHeadRef(gitDirectory: gitDirectory),
            index: fileContentFingerprint(gitDirectory.appendingPathComponent("index")),
            stash: stashFingerprint(gitDirectory: gitDirectory),
            refs: refsFingerprint(gitDirectory: gitDirectory)
        )
    }

    /// 读取 HEAD 的符号引用目标；detached（直接 hash）或缺失时返回 nil。
    static func readHeadRef(gitDirectory: URL) -> String? {
        let headURL = gitDirectory.appendingPathComponent("HEAD")
        guard let content = try? String(contentsOf: headURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            return nil
        }
        guard content.hasPrefix("ref:") else { return nil }
        return content
            .replacingOccurrences(of: "ref:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// linked worktree 的分支 ref / packed-refs / 共享 refs 都在 common dir；
    /// `commondir` 文件给出相对（或绝对）路径。普通仓库没有该文件，common dir 即自身（#156）。
    static func commonDirectory(gitDirectory: URL) -> URL {
        let commondirURL = gitDirectory.appendingPathComponent("commondir")
        guard let raw = try? String(contentsOf: commondirURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return gitDirectory
        }
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw, isDirectory: true).standardizedFileURL
        }
        return gitDirectory.appendingPathComponent(raw).standardizedFileURL
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
        // linked worktree 的分支 ref / packed-refs 在 common dir（#156）。
        let commonDir = commonDirectory(gitDirectory: gitDirectory)
        let refURL = commonDir.appendingPathComponent(refPath)
        if let refHash = try? String(contentsOf: refURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !refHash.isEmpty {
            return refHash
        }
        return readPackedRef(gitDirectory: commonDir, refPath: refPath)
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
        let commonDir = commonDirectory(gitDirectory: gitDirectory)
        let refs = fileContentFingerprint(commonDir.appendingPathComponent("refs/stash"))
        let logs = fileContentFingerprint(commonDir.appendingPathComponent("logs/refs/stash"))
        switch (refs, logs) {
        case (nil, nil): return nil
        case let (value?, nil), let (nil, value?): return value
        case let (refs?, logs?): return "\(refs):\(logs)"
        }
    }

    private static func refsFingerprint(gitDirectory: URL) -> String? {
        let commonDir = commonDirectory(gitDirectory: gitDirectory)
        let values = [
            directoryContentFingerprint(commonDir.appendingPathComponent("refs/heads")),
            directoryContentFingerprint(commonDir.appendingPathComponent("refs/remotes")),
            directoryContentFingerprint(commonDir.appendingPathComponent("refs/tags")),
            fileContentFingerprint(commonDir.appendingPathComponent("packed-refs")),
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
