import Foundation

/// 轻量级 pbxproj 解析器
/// 仅关注 File System Synchronized Group 模式下的 target -> 文件归属关系。
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
        let nativeTargetBlocks = parseSectionBlocks(named: "PBXNativeTarget", in: content)
        let rootGroupBlocks = parseSectionBlocks(named: "PBXFileSystemSynchronizedRootGroup", in: content)
        let exceptionBlocks = parseSectionBlocks(named: "PBXFileSystemSynchronizedBuildFileExceptionSet", in: content)

        let targets = nativeTargetBlocks.reduce(into: [String: ParsedTarget]()) { result, entry in
            let groups = parseIdentifierList(named: "fileSystemSynchronizedGroups", in: entry.body)
            let name = parseStringValue(named: "name", in: entry.body) ?? entry.comment
            result[entry.id] = ParsedTarget(id: entry.id, name: name, groupIDs: groups)
        }

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

        let graph = targets.reduce(into: [String: [TargetRoot]]()) { result, item in
            let target = item.value
            let roots = target.groupIDs.compactMap { groupID -> TargetRoot? in
                guard let group = rootGroups[groupID] else { return nil }
                let excluded = group.exceptionIDs
                    .compactMap { exceptions[$0] }
                    .filter { $0.targetID == target.id }
                    .reduce(into: Set<String>()) { partial, exception in
                        partial.formUnion(exception.excludedPaths)
                    }
                return TargetRoot(rootPath: group.path, excludedRelativePaths: excluded)
            }
            result[target.name] = roots
        }

        return MembershipGraph(targetRoots: graph)
    }

    private struct SectionEntry {
        let id: String
        let comment: String
        let body: String
    }

    private struct ParsedTarget {
        let id: String
        let name: String
        let groupIDs: [String]
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

    private static func parseSectionBlocks(named sectionName: String, in content: String) -> [SectionEntry] {
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

    private static func parseIdentifierList(named key: String, in body: String) -> [String] {
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

    private static func parseStringList(named key: String, in body: String) -> [String] {
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

    private static func parseStringValue(named key: String, in body: String) -> String? {
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

    private static func parseIdentifierValue(named key: String, in body: String) -> String? {
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
}
