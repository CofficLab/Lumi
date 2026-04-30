import Foundation

/// 轻量级 pbxproj 解析器
/// 同时支持 Xcode 16 File System Synchronized Group 与传统 Build Phase 模式。
enum XcodePBXProjParser {

    struct MembershipGraph {
        let targetRoots: [String: [TargetRoot]]
    }

    struct TargetRoot {
        let rootPath: String
        let excludedRelativePaths: Set<String>
    }

    static func parseMembershipGraph(projectURL: URL) throws -> MembershipGraph {
        let pbxprojURL = projectURL.appendingPathComponent("project.pbxproj")
        let content = try String(contentsOf: pbxprojURL, encoding: .utf8)
        return try parseMembershipGraph(contents: content)
    }

    static func parseMembershipGraph(contents: String) throws -> MembershipGraph {
        let parser = PBXContentParser(contents: contents)
        return MembershipGraph(targetRoots: parser.makeTargetRoots())
    }
}

private struct PBXContentParser {
    let contents: String

    private var nativeTargetBlocks: [SectionEntry] {
        parseSectionBlocks(named: "PBXNativeTarget", in: contents)
    }

    private var rootGroupBlocks: [SectionEntry] {
        parseSectionBlocks(named: "PBXFileSystemSynchronizedRootGroup", in: contents)
    }

    private var exceptionBlocks: [SectionEntry] {
        parseSectionBlocks(named: "PBXFileSystemSynchronizedBuildFileExceptionSet", in: contents)
    }

    private var projectBlocks: [SectionEntry] {
        parseSectionBlocks(named: "PBXProject", in: contents)
    }

    private var groupBlocks: [SectionEntry] {
        parseSectionBlocks(named: "PBXGroup", in: contents)
    }

    private var fileReferenceBlocks: [SectionEntry] {
        parseSectionBlocks(named: "PBXFileReference", in: contents)
    }

    private var buildFileBlocks: [SectionEntry] {
        parseSectionBlocks(named: "PBXBuildFile", in: contents)
    }

    private var sourcesBuildPhaseBlocks: [SectionEntry] {
        parseSectionBlocks(named: "PBXSourcesBuildPhase", in: contents)
    }

    private var headersBuildPhaseBlocks: [SectionEntry] {
        parseSectionBlocks(named: "PBXHeadersBuildPhase", in: contents)
    }

    private var resourcesBuildPhaseBlocks: [SectionEntry] {
        parseSectionBlocks(named: "PBXResourcesBuildPhase", in: contents)
    }

    func makeTargetRoots() -> [String: [XcodePBXProjParser.TargetRoot]] {
        let targets = parseTargets()
        let synchronizedRoots = parseSynchronizedRoots(targets: targets)
        let traditionalRoots = parseTraditionalRoots(targets: targets)

        return targets.values.reduce(into: [String: [XcodePBXProjParser.TargetRoot]]()) { result, target in
            let syncRoots = synchronizedRoots[target.id] ?? []
            let explicitRoots = traditionalRoots[target.id] ?? []
            let merged = deduplicate(syncRoots + explicitRoots)
            result[target.name] = merged
        }
    }

    private func parseTargets() -> [String: ParsedTarget] {
        nativeTargetBlocks.reduce(into: [String: ParsedTarget]()) { result, entry in
            let synchronizedGroupIDs = parseIdentifierList(named: "fileSystemSynchronizedGroups", in: entry.body)
            let buildPhaseIDs = parseIdentifierList(named: "buildPhases", in: entry.body)
            let name = parseStringValue(named: "name", in: entry.body) ?? entry.comment
            result[entry.id] = ParsedTarget(
                id: entry.id,
                name: name,
                synchronizedGroupIDs: synchronizedGroupIDs,
                buildPhaseIDs: buildPhaseIDs
            )
        }
    }

    private func parseSynchronizedRoots(
        targets: [String: ParsedTarget]
    ) -> [String: [XcodePBXProjParser.TargetRoot]] {
        let rootGroups = rootGroupBlocks.reduce(into: [String: ParsedRootGroup]()) { result, entry in
            guard let path = parseStringValue(named: "path", in: entry.body) else { return }
            let exceptionIDs = parseIdentifierList(named: "exceptions", in: entry.body)
            result[entry.id] = ParsedRootGroup(id: entry.id, path: path, exceptionIDs: exceptionIDs)
        }

        let exceptions = exceptionBlocks.reduce(into: [String: ParsedException]()) { result, entry in
            guard let targetID = parseIdentifierValue(named: "target", in: entry.body) else { return }
            let excludedPaths = Set(parseStringList(named: "membershipExceptions", in: entry.body))
            result[entry.id] = ParsedException(id: entry.id, targetID: targetID, excludedPaths: excludedPaths)
        }

        return targets.reduce(into: [String: [XcodePBXProjParser.TargetRoot]]()) { result, item in
            let target = item.value
            let roots = target.synchronizedGroupIDs.compactMap { groupID -> XcodePBXProjParser.TargetRoot? in
                guard let group = rootGroups[groupID] else { return nil }
                let excluded = group.exceptionIDs
                    .compactMap { exceptions[$0] }
                    .filter { $0.targetID == target.id }
                    .reduce(into: Set<String>()) { partial, exception in
                        partial.formUnion(exception.excludedPaths)
                    }
                return XcodePBXProjParser.TargetRoot(rootPath: group.path, excludedRelativePaths: excluded)
            }
            result[target.id] = roots
        }
    }

    private func parseTraditionalRoots(
        targets: [String: ParsedTarget]
    ) -> [String: [XcodePBXProjParser.TargetRoot]] {
        let projectRootGroupID = projectBlocks
            .compactMap { parseIdentifierValue(named: "mainGroup", in: $0.body) }
            .first

        let groups = groupBlocks.reduce(into: [String: ParsedGroup]()) { result, entry in
            result[entry.id] = ParsedGroup(
                id: entry.id,
                name: parseStringValue(named: "name", in: entry.body) ?? entry.comment,
                path: parseStringValue(named: "path", in: entry.body),
                sourceTree: parseStringValue(named: "sourceTree", in: entry.body) ?? "<group>",
                children: parseIdentifierList(named: "children", in: entry.body)
            )
        }

        let fileReferences = fileReferenceBlocks.reduce(into: [String: ParsedFileReference]()) { result, entry in
            result[entry.id] = ParsedFileReference(
                id: entry.id,
                name: parseStringValue(named: "name", in: entry.body) ?? entry.comment,
                path: parseStringValue(named: "path", in: entry.body),
                sourceTree: parseStringValue(named: "sourceTree", in: entry.body) ?? "<group>"
            )
        }

        let parentByNodeID = buildParentMap(groups: groups)
        let buildFiles = buildFileBlocks.reduce(into: [String: String]()) { result, entry in
            if let fileRefID = parseIdentifierValue(named: "fileRef", in: entry.body) {
                result[entry.id] = fileRefID
            }
        }

        let buildPhases = (sourcesBuildPhaseBlocks + headersBuildPhaseBlocks + resourcesBuildPhaseBlocks)
            .reduce(into: [String: [String]]()) { result, entry in
                result[entry.id] = parseIdentifierList(named: "files", in: entry.body)
            }

        func relativePath(for fileReferenceID: String) -> String? {
            guard let reference = fileReferences[fileReferenceID] else { return nil }
            return resolvePath(
                nodeID: fileReferenceID,
                path: reference.path ?? reference.name,
                sourceTree: reference.sourceTree,
                parentByNodeID: parentByNodeID,
                groups: groups,
                projectRootGroupID: projectRootGroupID
            )
        }

        return targets.reduce(into: [String: [XcodePBXProjParser.TargetRoot]]()) { result, item in
            let target = item.value
            let explicitFileRoots = target.buildPhaseIDs
                .flatMap { buildPhases[$0] ?? [] }
                .compactMap { buildFiles[$0] }
                .compactMap(relativePath(for:))
                .filter { !$0.isEmpty }
                .map { XcodePBXProjParser.TargetRoot(rootPath: $0, excludedRelativePaths: []) }
            result[target.id] = explicitFileRoots
        }
    }

    private func buildParentMap(groups: [String: ParsedGroup]) -> [String: String] {
        groups.values.reduce(into: [String: String]()) { result, group in
            for childID in group.children {
                result[childID] = group.id
            }
        }
    }

    private func resolvePath(
        nodeID: String,
        path: String?,
        sourceTree: String,
        parentByNodeID: [String: String],
        groups: [String: ParsedGroup],
        projectRootGroupID: String?
    ) -> String? {
        let cleanedPath = path?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch sourceTree {
        case "<absolute>":
            return cleanedPath
        case "SOURCE_ROOT":
            return cleanedPath
        case "<group>", "GROUP":
            let parentPath = resolveGroupPath(
                groupID: parentByNodeID[nodeID],
                parentByNodeID: parentByNodeID,
                groups: groups,
                projectRootGroupID: projectRootGroupID
            )
            return joinPath(parentPath, cleanedPath)
        default:
            return nil
        }
    }

    private func resolveGroupPath(
        groupID: String?,
        parentByNodeID: [String: String],
        groups: [String: ParsedGroup],
        projectRootGroupID: String?
    ) -> String? {
        guard let groupID, let group = groups[groupID] else { return nil }
        if groupID == projectRootGroupID {
            if group.sourceTree == "SOURCE_ROOT" {
                return group.path
            }
            return nil
        }

        let basePath = resolvePath(
            nodeID: groupID,
            path: group.path ?? group.name,
            sourceTree: group.sourceTree,
            parentByNodeID: parentByNodeID,
            groups: groups,
            projectRootGroupID: projectRootGroupID
        )

        if basePath == nil, group.sourceTree == "<group>" {
            return group.path ?? group.name
        }
        return basePath
    }

    private func joinPath(_ base: String?, _ child: String?) -> String? {
        guard let child, !child.isEmpty else { return base }
        guard let base, !base.isEmpty else { return child }
        if child.hasPrefix("/") {
            return child
        }
        return URL(fileURLWithPath: base).appendingPathComponent(child).path
    }

    private func deduplicate(
        _ roots: [XcodePBXProjParser.TargetRoot]
    ) -> [XcodePBXProjParser.TargetRoot] {
        var seen = Set<String>()
        return roots.filter { root in
            let key = "\(root.rootPath)|\(root.excludedRelativePaths.sorted().joined(separator: ","))"
            return seen.insert(key).inserted
        }
    }
}

private struct SectionEntry {
    let id: String
    let comment: String
    let body: String
}

private struct ParsedTarget {
    let id: String
    let name: String
    let synchronizedGroupIDs: [String]
    let buildPhaseIDs: [String]
}

private struct ParsedRootGroup {
    let id: String
    let path: String
    let exceptionIDs: [String]
}

private struct ParsedException {
    let id: String
    let targetID: String
    let excludedPaths: Set<String>
}

private struct ParsedGroup {
    let id: String
    let name: String
    let path: String?
    let sourceTree: String
    let children: [String]
}

private struct ParsedFileReference {
    let id: String
    let name: String
    let path: String?
    let sourceTree: String
}

private func parseSectionBlocks(named sectionName: String, in content: String) -> [SectionEntry] {
    guard
        let startRange = content.range(of: "/* Begin \(sectionName) section */"),
        let endRange = content.range(of: "/* End \(sectionName) section */")
    else {
        return []
    }

    let sectionContent = String(content[startRange.upperBound..<endRange.lowerBound])
    let pattern = #"(?ms)^\s*([A-Z0-9]+)\s*/\*\s*(.*?)\s*\*/\s*=\s*\{(.*?)^\s*\};"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(sectionContent.startIndex..<sectionContent.endIndex, in: sectionContent)

    return regex.matches(in: sectionContent, range: range).compactMap { match in
        guard
            let idRange = Range(match.range(at: 1), in: sectionContent),
            let commentRange = Range(match.range(at: 2), in: sectionContent),
            let bodyRange = Range(match.range(at: 3), in: sectionContent)
        else {
            return nil
        }
        return SectionEntry(
            id: String(sectionContent[idRange]),
            comment: String(sectionContent[commentRange]),
            body: String(sectionContent[bodyRange])
        )
    }
}

private func parseIdentifierList(named key: String, in body: String) -> [String] {
    let pattern = #"(?ms)\b\#(key)\s*=\s*\((.*?)\);"#
    let resolvedPattern = pattern.replacingOccurrences(of: #"\#(key)"#, with: NSRegularExpression.escapedPattern(for: key))
    guard
        let regex = try? NSRegularExpression(pattern: resolvedPattern),
        let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body)),
        let listRange = Range(match.range(at: 1), in: body)
    else {
        return []
    }

    let listBody = String(body[listRange])
    let linePattern = #"([A-Z0-9]+)\s*/\*"#
    guard let lineRegex = try? NSRegularExpression(pattern: linePattern) else { return [] }
    let listNSRange = NSRange(listBody.startIndex..<listBody.endIndex, in: listBody)
    return lineRegex.matches(in: listBody, range: listNSRange).compactMap { match in
        guard let idRange = Range(match.range(at: 1), in: listBody) else { return nil }
        return String(listBody[idRange])
    }
}

private func parseStringList(named key: String, in body: String) -> [String] {
    let pattern = #"(?ms)\b\#(key)\s*=\s*\((.*?)\);"#
    let resolvedPattern = pattern.replacingOccurrences(of: #"\#(key)"#, with: NSRegularExpression.escapedPattern(for: key))
    guard
        let regex = try? NSRegularExpression(pattern: resolvedPattern),
        let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body)),
        let listRange = Range(match.range(at: 1), in: body)
    else {
        return []
    }

    let listBody = String(body[listRange])
    return listBody
        .split(separator: "\n")
        .map { line in
            line
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
}

private func parseStringValue(named key: String, in body: String) -> String? {
    let pattern = #"\b\#(key)\s*=\s*(?:"([^"]+)"|([^;]+));"#
    let resolvedPattern = pattern.replacingOccurrences(of: #"\#(key)"#, with: NSRegularExpression.escapedPattern(for: key))
    guard
        let regex = try? NSRegularExpression(pattern: resolvedPattern),
        let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body))
    else {
        return nil
    }

    for index in 1...2 {
        let nsRange = match.range(at: index)
        guard nsRange.location != NSNotFound, let range = Range(nsRange, in: body) else { continue }
        return body[range].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return nil
}

private func parseIdentifierValue(named key: String, in body: String) -> String? {
    let pattern = #"\b\#(key)\s*=\s*([A-Z0-9]+)\s*/\*"#
    let resolvedPattern = pattern.replacingOccurrences(of: #"\#(key)"#, with: NSRegularExpression.escapedPattern(for: key))
    guard
        let regex = try? NSRegularExpression(pattern: resolvedPattern),
        let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body)),
        let range = Range(match.range(at: 1), in: body)
    else {
        return nil
    }
    return String(body[range])
}
