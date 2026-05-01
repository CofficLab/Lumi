import Foundation
import PathKit
import XcodeProj

/// 基于 XcodeProj 的 pbxproj membership 解析适配层。
enum XcodePBXProjParser {

    struct MembershipGraph {
        let targetRoots: [String: [TargetRoot]]
    }

    struct TargetRoot {
        let rootPath: String
        let excludedRelativePaths: Set<String>
    }

    static func parseMembershipGraph(projectURL: URL) throws -> MembershipGraph {
        let xcodeProj = try XcodeProj(pathString: projectURL.path)
        return try parseMembershipGraph(xcodeProj: xcodeProj, projectURL: projectURL)
    }

    static func parseMembershipGraph(contents: String) throws -> MembershipGraph {
        guard !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return MembershipGraph(targetRoots: [:])
        }

        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectURL = temporaryRoot.appendingPathComponent("Fixture.xcodeproj", isDirectory: true)
        let pbxprojURL = projectURL.appendingPathComponent("project.pbxproj")

        try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try contents.write(to: pbxprojURL, atomically: true, encoding: .utf8)
        return try parseMembershipGraph(projectURL: projectURL)
    }

    private static func parseMembershipGraph(xcodeProj: XcodeProj, projectURL: URL) throws -> MembershipGraph {
        let parser = PBXMembershipParser(
            pbxproj: xcodeProj.pbxproj,
            projectURL: projectURL
        )
        return MembershipGraph(targetRoots: try parser.makeTargetRoots())
    }
}

private struct PBXMembershipParser {
    let pbxproj: PBXProj
    let projectURL: URL

    private var sourceRoot: Path {
        Path(projectURL.deletingLastPathComponent().path)
    }

    func makeTargetRoots() throws -> [String: [XcodePBXProjParser.TargetRoot]] {
        try pbxproj.nativeTargets.reduce(into: [String: [XcodePBXProjParser.TargetRoot]]()) { result, target in
            let synchronizedRoots = try synchronizedRoots(for: target)
            let explicitRoots = try traditionalRoots(for: target)
            result[target.name] = deduplicate(synchronizedRoots + explicitRoots)
        }
    }

    private func synchronizedRoots(for target: PBXNativeTarget) throws -> [XcodePBXProjParser.TargetRoot] {
        let groups = target.fileSystemSynchronizedGroups ?? []
        return try groups.compactMap { group in
            guard let rootPath = try normalizedPath(for: group) else { return nil }
            let excluded = exceptionMembershipExclusions(in: group, targetName: target.name)
            return XcodePBXProjParser.TargetRoot(
                rootPath: rootPath,
                excludedRelativePaths: excluded
            )
        }
    }

    private func traditionalRoots(for target: PBXNativeTarget) throws -> [XcodePBXProjParser.TargetRoot] {
        try target.buildPhases
            .filter(isMembershipBuildPhase(_:))
            .flatMap { $0.files ?? [] }
            .compactMap { buildFile in
                guard let file = buildFile.file else { return nil }
                guard let rootPath = try normalizedPath(for: file) else { return nil }
                return XcodePBXProjParser.TargetRoot(rootPath: rootPath, excludedRelativePaths: [])
            }
    }

    private func isMembershipBuildPhase(_ phase: PBXBuildPhase) -> Bool {
        phase is PBXSourcesBuildPhase || phase is PBXHeadersBuildPhase || phase is PBXResourcesBuildPhase
    }

    private func exceptionMembershipExclusions(
        in group: PBXFileSystemSynchronizedRootGroup,
        targetName: String
    ) -> Set<String> {
        Set(
            (group.exceptions ?? [])
                .compactMap { $0 as? PBXFileSystemSynchronizedBuildFileExceptionSet }
                .filter { $0.target?.name == targetName }
                .flatMap { $0.membershipExceptions ?? [] }
        )
    }

    private func normalizedPath(for fileElement: PBXFileElement) throws -> String? {
        guard let fullPath = try fileElement.fullPath(sourceRoot: sourceRoot) else { return nil }
        return normalizedPath(from: fullPath)
    }

    private func normalizedPath(from fullPath: Path) -> String {
        let absolutePath = fullPath.absolute()
        let absoluteString = absolutePath.string
        let sourceRootString = sourceRoot.absolute().string

        if absoluteString == sourceRootString {
            return "."
        }

        let prefix = sourceRootString.hasSuffix("/") ? sourceRootString : sourceRootString + "/"
        if absoluteString.hasPrefix(prefix) {
            return String(absoluteString.dropFirst(prefix.count))
        }

        return absoluteString
    }

    private func deduplicate(_ roots: [XcodePBXProjParser.TargetRoot]) -> [XcodePBXProjParser.TargetRoot] {
        var seen = Set<String>()
        return roots.filter { root in
            let key = "\(root.rootPath)|\(root.excludedRelativePaths.sorted().joined(separator: ","))"
            return seen.insert(key).inserted
        }
    }
}
