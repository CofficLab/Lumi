import Foundation

/// One printable side of a physical output sheet.
public struct OutputSheet: Equatable, Sendable {
    public enum Side: String, Equatable, Sendable {
        case front
        case back
    }

    public let index: Int
    public let physicalSheetIndex: Int
    public let signatureIndex: Int
    public let sheetIndexInSignature: Int
    public let side: Side
    public let leftPage: Int
    public let rightPage: Int

    public init(
        index: Int,
        physicalSheetIndex: Int,
        signatureIndex: Int = 0,
        sheetIndexInSignature: Int = 0,
        side: Side,
        leftPage: Int,
        rightPage: Int
    ) {
        self.index = index
        self.physicalSheetIndex = physicalSheetIndex
        self.signatureIndex = signatureIndex
        self.sheetIndexInSignature = sheetIndexInSignature
        self.side = side
        self.leftPage = leftPage
        self.rightPage = rightPage
    }

    public static func blank(
        index: Int,
        physicalSheetIndex: Int,
        signatureIndex: Int = 0,
        sheetIndexInSignature: Int = 0,
        side: Side
    ) -> Self {
        Self(
            index: index,
            physicalSheetIndex: physicalSheetIndex,
            signatureIndex: signatureIndex,
            sheetIndexInSignature: sheetIndexInSignature,
            side: side,
            leftPage: 0,
            rightPage: 0
        )
    }
}

/// A physical sheet with one or two printable sides.
public struct PhysicalSheet: Equatable, Sendable {
    public let index: Int
    public let signatureIndex: Int
    public let sheetIndexInSignature: Int
    public let front: OutputSheet
    public let back: OutputSheet?

    public init(
        index: Int,
        signatureIndex: Int,
        sheetIndexInSignature: Int,
        front: OutputSheet,
        back: OutputSheet?
    ) {
        self.index = index
        self.signatureIndex = signatureIndex
        self.sheetIndexInSignature = sheetIndexInSignature
        self.front = front
        self.back = back
    }

    public var outputSides: [OutputSheet] {
        if let back { return [front, back] }
        return [front]
    }
}
