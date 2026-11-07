import Foundation

/// A contiguous page range in a source PDF.
public struct PDFSplitSegment: Identifiable, Equatable, Sendable {
    public let index: Int
    public let startPage: Int
    public let endPage: Int

    public init(index: Int, startPage: Int, endPage: Int) {
        self.index = index
        self.startPage = startPage
        self.endPage = endPage
    }

    public var id: Int { index }
    public var rangeKey: String { "\(startPage)-\(endPage)" }
    public var pageCount: Int { endPage - startPage + 1 }

    public func fileName(baseName: String) -> String {
        "\(baseName)-part-\(index).pdf"
    }
}

/// A planned split output and its destination file name.
public struct PDFSplitOutput: Identifiable, Equatable, Sendable {
    public let segment: PDFSplitSegment
    public let fileName: String

    public init(segment: PDFSplitSegment, fileName: String) {
        self.segment = segment
        self.fileName = fileName
    }

    public var id: Int { segment.id }
}

/// Pure parsing and planning for PDF split points.
public enum PDFSplitPlan {
    public enum ValidationError: LocalizedError, Equatable, Sendable {
        case invalidToken(String)
        case cutPointOutOfRange(Int, pageCount: Int)

        public var errorDescription: String? {
            switch self {
            case .invalidToken(let token):
                "Invalid page number: \(token)"
            case .cutPointOutOfRange(let page, let pageCount):
                "Cut points must be between 1 and \(max(pageCount - 1, 0)) (found \(page))."
            }
        }
    }

    public static func parseCutPoints(
        _ text: String,
        pageCount: Int
    ) -> Result<[Int], ValidationError> {
        let normalized = text.replacingOccurrences(of: "，", with: ",")
        let tokens = normalized.split { character in
            character == "," || character.isWhitespace
        }

        var points = Set<Int>()
        for token in tokens {
            guard let page = Int(token) else {
                return .failure(.invalidToken(String(token)))
            }
            guard page >= 1, page < pageCount else {
                return .failure(.cutPointOutOfRange(page, pageCount: pageCount))
            }
            points.insert(page)
        }
        return .success(points.sorted())
    }

    public static func segments(
        pageCount: Int,
        cutPoints: [Int]
    ) -> [PDFSplitSegment] {
        guard pageCount > 0 else { return [] }
        let validPoints = Array(Set(cutPoints.filter { $0 >= 1 && $0 < pageCount })).sorted()
        var startPage = 1
        var result: [PDFSplitSegment] = []

        for cutPoint in validPoints {
            result.append(PDFSplitSegment(
                index: result.count + 1,
                startPage: startPage,
                endPage: cutPoint
            ))
            startPage = cutPoint + 1
        }
        result.append(PDFSplitSegment(
            index: result.count + 1,
            startPage: startPage,
            endPage: pageCount
        ))
        return result
    }
}
