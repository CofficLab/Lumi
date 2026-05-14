import Foundation

public enum PackageManifestSyntax {
    public struct DependencyLink: Equatable {
        public let url: URL
        public let range: NSRange
        public let rawURL: String

        public init(url: URL, range: NSRange, rawURL: String) {
            self.url = url
            self.range = range
            self.rawURL = rawURL
        }
    }

    public struct DependencyRequirement: Equatable {
        public enum Kind: String, Equatable {
            case from
            case exact
            case upToNextMajor
            case upToNextMinor
            case branch
            case revision
            case path
        }

        public let kind: Kind
        public let value: String
        public let range: NSRange

        public init(kind: Kind, value: String, range: NSRange) {
            self.kind = kind
            self.value = value
            self.range = range
        }

        public var summary: String {
            switch kind {
            case .from:
                return "Version requirement: `from \(value)`"
            case .exact:
                return "Version requirement: `exact \(value)`"
            case .upToNextMajor:
                return "Version requirement: `upToNextMajor(from: \(value))`"
            case .upToNextMinor:
                return "Version requirement: `upToNextMinor(from: \(value))`"
            case .branch:
                return "Version requirement: `branch(\(value))`"
            case .revision:
                return "Version requirement: `revision(\(value))`"
            case .path:
                return "Local package path: `\(value)`"
            }
        }
    }

    public struct DependencyDescriptor: Equatable {
        public let url: URL
        public let urlRange: NSRange
        public let rawURL: String
        public let invocationRange: NSRange
        public let requirement: DependencyRequirement?

        public init(
            url: URL,
            urlRange: NSRange,
            rawURL: String,
            invocationRange: NSRange,
            requirement: DependencyRequirement?
        ) {
            self.url = url
            self.urlRange = urlRange
            self.rawURL = rawURL
            self.invocationRange = invocationRange
            self.requirement = requirement
        }

        public var repositoryName: String {
            let lastPath = url.deletingPathExtension().lastPathComponent
            return lastPath.isEmpty ? rawURL : lastPath
        }
    }

    public static func dependencyLink(at utf16Offset: Int, in content: String) -> DependencyLink? {
        dependency(at: utf16Offset, in: content).map {
            DependencyLink(url: $0.url, range: $0.urlRange, rawURL: $0.rawURL)
        }
    }

    public static func hoverMarkdown(line: Int, character: Int, in content: String) -> String? {
        guard let utf16Offset = utf16Offset(in: content, line: line, character: character),
              let dependency = dependency(at: utf16Offset, in: content) else {
            return nil
        }

        var sections = [
            "### Swift Package Dependency",
            "- Repository: `\(dependency.repositoryName)`",
            "- URL: `\(dependency.rawURL)`"
        ]
        if let requirement = dependency.requirement {
            sections.append("- \(requirement.summary)")
        } else {
            sections.append("- Version requirement: not explicitly declared")
        }
        return sections.joined(separator: "\n")
    }

    public static func dependency(at utf16Offset: Int, in content: String) -> DependencyDescriptor? {
        for invocationRange in packageInvocationRanges(in: content) {
            guard NSLocationInRange(utf16Offset, invocationRange) else { continue }
            guard let dependency = dependency(in: content, invocationRange: invocationRange) else { continue }
            if NSLocationInRange(utf16Offset, dependency.urlRange) ||
                dependency.requirement.map({ NSLocationInRange(utf16Offset, $0.range) }) == true ||
                NSLocationInRange(utf16Offset, invocationRange) {
                return dependency
            }
        }
        return nil
    }

    private static func dependency(in content: String, invocationRange: NSRange) -> DependencyDescriptor? {
        let invocation = (content as NSString).substring(with: invocationRange)
        guard let urlMatch = firstMatch(
            #"\burl\s*:\s*"([^"]+)""#,
            in: invocation
        ) else {
            return nil
        }

        let rawURL = (invocation as NSString).substring(with: urlMatch.range(at: 1))
        guard let url = URL(string: rawURL) else { return nil }

        let urlRange = NSRange(
            location: invocationRange.location + urlMatch.range(at: 1).location,
            length: urlMatch.range(at: 1).length
        )

        let requirementPatterns: [(DependencyRequirement.Kind, String)] = [
            (.upToNextMajor, #"upToNextMajor\s*\(\s*from\s*:\s*"([^"]+)"\s*\)"#),
            (.upToNextMinor, #"upToNextMinor\s*\(\s*from\s*:\s*"([^"]+)"\s*\)"#),
            (.from, #"\bfrom\s*:\s*"([^"]+)""#),
            (.exact, #"\bexact\s*:\s*"([^"]+)""#),
            (.branch, #"\bbranch\s*:\s*"([^"]+)""#),
            (.revision, #"\brevision\s*:\s*"([^"]+)""#),
            (.path, #"\bpath\s*:\s*"([^"]+)""#)
        ]

        let requirement = requirementPatterns.compactMap { kind, pattern -> DependencyRequirement? in
            guard let match = firstMatch(pattern, in: invocation) else { return nil }
            let localRange = match.range(at: 1)
            return DependencyRequirement(
                kind: kind,
                value: (invocation as NSString).substring(with: localRange),
                range: NSRange(
                    location: invocationRange.location + localRange.location,
                    length: localRange.length
                )
            )
        }.first

        return DependencyDescriptor(
            url: url,
            urlRange: urlRange,
            rawURL: rawURL,
            invocationRange: invocationRange,
            requirement: requirement
        )
    }

    private static func packageInvocationRanges(in content: String) -> [NSRange] {
        let nsContent = content as NSString
        let searchRange = NSRange(location: 0, length: nsContent.length)
        guard let regex = try? NSRegularExpression(pattern: #"\.package\s*\("#) else {
            return []
        }

        return regex.matches(in: content, range: searchRange).compactMap { match in
            let openParenLocation = match.range.location + match.range.length - 1
            return balancedInvocationRange(
                in: content,
                invocationStart: match.range.location,
                openParenLocation: openParenLocation
            )
        }
    }

    private static func balancedInvocationRange(
        in content: String,
        invocationStart: Int,
        openParenLocation: Int
    ) -> NSRange? {
        let utf16 = Array(content.utf16)
        guard openParenLocation >= 0, openParenLocation < utf16.count else { return nil }

        var depth = 0
        var index = openParenLocation
        while index < utf16.count {
            let scalar = utf16[index]
            if scalar == 40 {
                depth += 1
            } else if scalar == 41 {
                depth -= 1
                if depth == 0 {
                    return NSRange(location: invocationStart, length: index - invocationStart + 1)
                }
            }
            index += 1
        }
        return nil
    }

    private static func firstMatch(_ pattern: String, in content: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: content, range: NSRange(location: 0, length: content.utf16.count))
    }

    private static func utf16Offset(in content: String, line: Int, character: Int) -> Int? {
        guard line >= 0, character >= 0 else { return nil }
        var currentLine = 0
        var currentCharacter = 0
        var currentOffset = 0

        for scalar in content.utf16 {
            if currentLine == line && currentCharacter == character {
                return currentOffset
            }

            currentOffset += 1
            if scalar == 10 {
                currentLine += 1
                currentCharacter = 0
            } else {
                currentCharacter += 1
            }
        }

        return (currentLine == line && currentCharacter == character) ? currentOffset : nil
    }
}
