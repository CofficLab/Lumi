import Foundation

public struct XcodePackageReference: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let location: String
    public let kind: PackageDependencyKind
    public let requirementKind: String?
    public let version: String?
    public let branch: String?
    public let revision: String?

    public var identity: String {
        PackageResolved.normalizeIdentity(location)
    }
}

public enum XcodePackageReferenceParser {
    public static func parse(projectURL: URL) throws -> [XcodePackageReference] {
        let pbxprojURL = projectURL.appendingPathComponent("project.pbxproj")
        var encoding = String.Encoding.utf8
        let contents = try String(contentsOf: pbxprojURL, usedEncoding: &encoding)
        return parse(contents: contents)
    }

    public static func parse(contents: String) -> [XcodePackageReference] {
        parseRemoteReferences(contents: contents) + parseLocalReferences(contents: contents)
    }

    private static func parseRemoteReferences(contents: String) -> [XcodePackageReference] {
        objects(in: contents, isa: "XCRemoteSwiftPackageReference").compactMap { object in
            guard let location = field("repositoryURL", in: object.body) else { return nil }
            let displayName = object.comment ?? PackageResolved.identityFromLocation(location)
            let requirement = block("requirement", in: object.body)
            return XcodePackageReference(
                id: object.id,
                displayName: displayName,
                location: location,
                kind: .remote,
                requirementKind: requirement.flatMap { field("kind", in: $0) },
                version: requirement.flatMap { field("minimumVersion", in: $0) ?? field("exactVersion", in: $0) },
                branch: requirement.flatMap { field("branch", in: $0) },
                revision: requirement.flatMap { field("revision", in: $0) }
            )
        }
    }

    private static func parseLocalReferences(contents: String) -> [XcodePackageReference] {
        objects(in: contents, isa: "XCLocalSwiftPackageReference").compactMap { object in
            guard let path = field("relativePath", in: object.body) else { return nil }
            let displayName = object.comment ?? URL(fileURLWithPath: path).lastPathComponent
            return XcodePackageReference(
                id: object.id,
                displayName: displayName,
                location: path,
                kind: .local,
                requirementKind: nil,
                version: nil,
                branch: nil,
                revision: nil
            )
        }
    }

    private struct ParsedObject {
        let id: String
        let comment: String?
        let body: String
    }

    private static func objects(in contents: String, isa: String) -> [ParsedObject] {
        let pattern = #"(?s)([A-Fa-f0-9]+)\s*/\*\s*([^*]+?)\s*\*/\s*=\s*\{\s*isa\s*=\s*\#(isa)\s*;(.*?)\n\t\t\};"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(contents.startIndex..<contents.endIndex, in: contents)
        return regex.matches(in: contents, range: nsRange).compactMap { match in
            guard let idRange = Range(match.range(at: 1), in: contents),
                  let commentRange = Range(match.range(at: 2), in: contents),
                  let bodyRange = Range(match.range(at: 3), in: contents) else {
                return nil
            }
            let rawComment = String(contents[commentRange])
            return ParsedObject(
                id: String(contents[idRange]),
                comment: cleanComment(rawComment, isa: isa),
                body: String(contents[bodyRange])
            )
        }
    }

    private static func cleanComment(_ comment: String, isa: String) -> String? {
        let prefix = isa + " \""
        guard comment.hasPrefix(prefix), comment.hasSuffix("\"") else {
            return comment.isEmpty ? nil : comment
        }
        return String(comment.dropFirst(prefix.count).dropLast())
    }

    private static func field(_ name: String, in body: String) -> String? {
        let pattern = #"\b\#(name)\s*=\s*("[^"]*"|[^;\n]+)\s*;"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body)),
              let range = Range(match.range(at: 1), in: body) else {
            return nil
        }
        return unquote(String(body[range]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func block(_ name: String, in body: String) -> String? {
        let pattern = #"(?s)\b\#(name)\s*=\s*\{(.*?)\};"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body)),
              let range = Range(match.range(at: 1), in: body) else {
            return nil
        }
        return String(body[range])
    }

    private static func unquote(_ value: String) -> String {
        guard value.hasPrefix("\""), value.hasSuffix("\"") else { return value }
        return String(value.dropFirst().dropLast())
    }
}
