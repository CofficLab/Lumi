import Foundation

public enum LargeFileMode: Equatable, Sendable {
    case normal
    case medium
    case large
    case mega

    public static let mediumThreshold: Int64 = 1 * 1024 * 1024
    public static let largeThreshold: Int64 = 10 * 1024 * 1024
    public static let megaThreshold: Int64 = 50 * 1024 * 1024

    public static func mode(for fileSize: Int64) -> LargeFileMode {
        if fileSize >= megaThreshold {
            return .mega
        } else if fileSize >= largeThreshold {
            return .large
        } else if fileSize >= mediumThreshold {
            return .medium
        }
        return .normal
    }

    public var isSemanticTokensDisabled: Bool {
        switch self {
        case .normal: return false
        case .medium, .large, .mega: return true
        }
    }

    public var isInlayHintsDisabled: Bool {
        switch self {
        case .normal: return false
        case .medium: return false
        case .large, .mega: return true
        }
    }

    public var isFoldingDisabled: Bool {
        switch self {
        case .normal, .medium: return false
        case .large, .mega: return true
        }
    }

    public var isMinimapDisabled: Bool {
        switch self {
        case .normal, .medium: return false
        case .large, .mega: return true
        }
    }

    public var isLongLineProtectionEnabled: Bool {
        switch self {
        case .normal, .medium: return false
        case .large, .mega: return true
        }
    }

    public var maxSyntaxHighlightLines: Int {
        switch self {
        case .normal: return .max
        case .medium: return 50_000
        case .large: return 10_000
        case .mega: return 1_000
        }
    }

    public var isReadOnly: Bool {
        switch self {
        case .normal, .medium, .large: return false
        case .mega: return true
        }
    }
}

public struct LongestDetectedLine: Equatable, Sendable {
    public let line: Int
    public let length: Int

    public init(line: Int, length: Int) {
        self.line = line
        self.length = length
    }
}

public enum LongLineDetector: Sendable {
    public static let threshold: Int = 10_000

    public static func findLongestLine(in text: String, limit: Int = threshold) -> LongestDetectedLine? {
        var longestLine = 0
        var longestLength = 0
        var currentLine = 0
        var currentLength = 0

        for scalar in text.unicodeScalars {
            if scalar == "\n" {
                if currentLength > longestLength {
                    longestLength = currentLength
                    longestLine = currentLine
                    if longestLength >= limit {
                        return LongestDetectedLine(line: longestLine, length: longestLength)
                    }
                }
                currentLine += 1
                currentLength = 0
            } else {
                currentLength += 1
            }
        }

        if currentLength > longestLength {
            longestLength = currentLength
            longestLine = currentLine
        }

        return longestLength >= limit ? LongestDetectedLine(line: longestLine, length: longestLength) : nil
    }
}
