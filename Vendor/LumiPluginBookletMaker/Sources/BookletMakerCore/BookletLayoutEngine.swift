import CoreGraphics
import Foundation

/// Deterministic booklet imposition and display geometry algorithms.
public enum BookletLayoutEngine {
    public static func paddedInputCount(
        _ rawCount: Int,
        layout: LayoutMode,
        pad: Bool,
        signaturePageCount: Int = 4
    ) -> Int {
        guard rawCount > 0 else { return 0 }
        switch layout {
        case .bookletFold:
            return ((rawCount + 3) / 4) * 4
        case .signatureFold:
            return signatureRanges(
                inputPageCount: rawCount,
                pagesPerSignature: signaturePageCount
            ).reduce(0) { $0 + $1.paddedPageCount }
        case .simplePair:
            guard pad else { return rawCount }
            return rawCount + (rawCount.isMultiple(of: 2) ? 0 : 1)
        }
    }

    public static func signatureCount(inputPageCount: Int, pagesPerSignature: Int) -> Int {
        guard inputPageCount > 0 else { return 0 }
        let capacity = normalizedSignaturePageCount(pagesPerSignature)
        return (inputPageCount + capacity - 1) / capacity
    }

    public static func outputSideCount(forPaddedInputCount count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (count + 1) / 2
    }

    public static func physicalSheetCount(forPaddedInputCount count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (count + 3) / 4
    }

    public static func bookletFoldMapping(
        outputIndex: Int,
        paddedInputCount count: Int
    ) -> (left: Int, right: Int) {
        let physicalSheetIndex = outputIndex / 2
        if outputIndex.isMultiple(of: 2) {
            return (count - 2 * physicalSheetIndex, 1 + 2 * physicalSheetIndex)
        }
        return (2 + 2 * physicalSheetIndex, count - 1 - 2 * physicalSheetIndex)
    }

    public static func simplePairMapping(
        outputIndex: Int,
        paddedInputCount count: Int
    ) -> (left: Int, right: Int) {
        let left = 2 * outputIndex + 1
        let right = left + 1
        return (left <= count ? left : 0, right <= count ? right : 0)
    }

    public static func buildOutputSides(
        inputPageCount: Int,
        settings: BookletSettings
    ) -> [OutputSheet] {
        if settings.layout == .signatureFold {
            return buildSignatureOutputSides(
                inputPageCount: inputPageCount,
                pagesPerSignature: settings.signaturePageCount
            )
        }

        let padded = paddedInputCount(
            inputPageCount,
            layout: settings.layout,
            pad: settings.padBlankPage,
            signaturePageCount: settings.signaturePageCount
        )
        let total = outputSideCount(forPaddedInputCount: padded)
        guard total > 0 else { return [] }

        return (0..<total).map { index in
            let pair: (Int, Int)
            let physicalSheetIndex: Int
            let side: OutputSheet.Side
            switch settings.layout {
            case .bookletFold:
                pair = bookletFoldMapping(outputIndex: index, paddedInputCount: padded)
                physicalSheetIndex = index / 2
                side = index.isMultiple(of: 2) ? .front : .back
            case .simplePair:
                pair = simplePairMapping(outputIndex: index, paddedInputCount: padded)
                physicalSheetIndex = index
                side = .front
            case .signatureFold:
                preconditionFailure("Signature-fold output uses the signature planner")
            }

            return OutputSheet(
                index: index,
                physicalSheetIndex: physicalSheetIndex,
                signatureIndex: 0,
                sheetIndexInSignature: settings.layout == .bookletFold ? index / 2 : index,
                side: side,
                leftPage: pair.0 <= inputPageCount ? pair.0 : 0,
                rightPage: pair.1 <= inputPageCount ? pair.1 : 0
            )
        }
    }

    public static func buildPhysicalSheets(
        inputPageCount: Int,
        settings: BookletSettings
    ) -> [PhysicalSheet] {
        let sides = buildOutputSides(inputPageCount: inputPageCount, settings: settings)
        let grouped = Dictionary(grouping: sides, by: \.physicalSheetIndex)
        return grouped.keys.sorted().compactMap { index in
            guard let group = grouped[index],
                  let front = group.first(where: { $0.side == .front }) else { return nil }
            return PhysicalSheet(
                index: index,
                signatureIndex: front.signatureIndex,
                sheetIndexInSignature: front.sheetIndexInSignature,
                front: front,
                back: group.first(where: { $0.side == .back })
            )
        }
    }

    public static func leftRect(for settings: BookletSettings) -> CGRect {
        CGRect(
            origin: settings.leftCellOrigin(),
            size: CGSize(width: settings.cellWidthInPoints(), height: settings.cellHeightInPoints())
        )
    }

    public static func rightRect(for settings: BookletSettings) -> CGRect {
        CGRect(
            origin: settings.rightCellOrigin(),
            size: CGSize(width: settings.cellWidthInPoints(), height: settings.cellHeightInPoints())
        )
    }

    public static func fitRect(aspectRatio: CGFloat, into target: CGRect) -> CGRect {
        guard target.width > 0, target.height > 0, aspectRatio > 0 else { return target }
        let cellAspect = target.width / target.height
        let size: CGSize
        if aspectRatio >= cellAspect {
            let width = target.width
            size = CGSize(width: width, height: width / aspectRatio)
        } else {
            let height = target.height
            size = CGSize(width: height * aspectRatio, height: height)
        }
        return CGRect(
            x: target.midX - size.width / 2,
            y: target.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    public static func paperDisplaySize(paper: PaperSize, within bounds: CGSize) -> CGSize {
        let aspect = paper.widthMM / paper.heightMM
        guard aspect > 0, bounds.width > 0, bounds.height > 0 else { return bounds }
        let width = min(bounds.width, bounds.height * aspect)
        return CGSize(width: width, height: width / aspect)
    }

    public static func landscapePaperDisplaySize(paper: PaperSize, within bounds: CGSize) -> CGSize {
        let aspect = paper.heightMM / paper.widthMM
        guard aspect > 0, bounds.width > 0, bounds.height > 0 else { return bounds }
        let width = min(bounds.width, bounds.height * aspect)
        return CGSize(width: width, height: width / aspect)
    }

    public static func displayUnit(for paperWidth: CGFloat, paper: PaperSize) -> CGFloat {
        guard paper.heightMM > 0 else { return 1 }
        return paperWidth / paper.heightMM
    }

    private struct SignatureRange {
        let index: Int
        let startPage: Int
        let sourcePageCount: Int
        let paddedPageCount: Int
    }

    private static func normalizedSignaturePageCount(_ requested: Int) -> Int {
        max(4, (requested / 4) * 4)
    }

    private static func signatureRanges(
        inputPageCount: Int,
        pagesPerSignature: Int
    ) -> [SignatureRange] {
        guard inputPageCount > 0 else { return [] }
        let capacity = normalizedSignaturePageCount(pagesPerSignature)
        var ranges: [SignatureRange] = []
        var startPage = 1
        while startPage <= inputPageCount {
            let sourceCount = min(capacity, inputPageCount - startPage + 1)
            ranges.append(SignatureRange(
                index: ranges.count,
                startPage: startPage,
                sourcePageCount: sourceCount,
                paddedPageCount: ((sourceCount + 3) / 4) * 4
            ))
            startPage += sourceCount
        }
        return ranges
    }

    private static func buildSignatureOutputSides(
        inputPageCount: Int,
        pagesPerSignature: Int
    ) -> [OutputSheet] {
        var output: [OutputSheet] = []
        var physicalSheetOffset = 0

        for signature in signatureRanges(
            inputPageCount: inputPageCount,
            pagesPerSignature: pagesPerSignature
        ) {
            let sideCount = outputSideCount(forPaddedInputCount: signature.paddedPageCount)
            for localIndex in 0..<sideCount {
                let pair = bookletFoldMapping(
                    outputIndex: localIndex,
                    paddedInputCount: signature.paddedPageCount
                )
                func sourcePage(_ localPage: Int) -> Int {
                    guard localPage > 0, localPage <= signature.sourcePageCount else { return 0 }
                    return signature.startPage + localPage - 1
                }
                output.append(OutputSheet(
                    index: output.count,
                    physicalSheetIndex: physicalSheetOffset + localIndex / 2,
                    signatureIndex: signature.index,
                    sheetIndexInSignature: localIndex / 2,
                    side: localIndex.isMultiple(of: 2) ? .front : .back,
                    leftPage: sourcePage(pair.left),
                    rightPage: sourcePage(pair.right)
                ))
            }
            physicalSheetOffset += signature.paddedPageCount / 4
        }
        return output
    }
}
