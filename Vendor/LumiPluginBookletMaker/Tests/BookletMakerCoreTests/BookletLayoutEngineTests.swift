import CoreGraphics
import Foundation
import Testing
@testable import BookletMakerCore

// MARK: - Padding

@Suite("BookletLayoutEngine / padding")
struct BookletLayoutEnginePaddingTests {
    @Test("booklet fold always pads up to a multiple of four")
    func bookletFoldPadding() {
        for raw in 1...12 {
            let padded = BookletLayoutEngine.paddedInputCount(
                raw, layout: .bookletFold, pad: true
            )
            #expect(padded % 4 == 0, "\(raw) pages padded to \(padded), not a multiple of 4")
            #expect(padded >= raw)
            #expect(padded - raw < 4)
        }
    }

    @Test("booklet fold ignores the pad flag because folding requires it")
    func bookletFoldIgnoresPadFlag() {
        #expect(
            BookletLayoutEngine.paddedInputCount(6, layout: .bookletFold, pad: false)
                == BookletLayoutEngine.paddedInputCount(6, layout: .bookletFold, pad: true)
        )
    }

    @Test("simple pair pads to an even count only when padding is on")
    func simplePairPadding() {
        #expect(BookletLayoutEngine.paddedInputCount(6, layout: .simplePair, pad: true) == 6)
        #expect(BookletLayoutEngine.paddedInputCount(6, layout: .simplePair, pad: false) == 6)
        #expect(BookletLayoutEngine.paddedInputCount(7, layout: .simplePair, pad: true) == 8)
        #expect(BookletLayoutEngine.paddedInputCount(7, layout: .simplePair, pad: false) == 7)
    }

    @Test("signature fold pads each signature independently")
    func signatureFoldPadding() {
        // 10 pages over signatures of 8 → 8 + 2 padded to 4 → 8 + 4 = 12.
        #expect(
            BookletLayoutEngine.paddedInputCount(
                10, layout: .signatureFold, pad: true, signaturePageCount: 8
            ) == 12
        )
        #expect(
            BookletLayoutEngine.paddedInputCount(
                9, layout: .signatureFold, pad: true, signaturePageCount: 8
            ) == 12
        )
        #expect(
            BookletLayoutEngine.paddedInputCount(
                8, layout: .signatureFold, pad: true, signaturePageCount: 8
            ) == 8
        )
    }

    @Test("non-positive input never pads")
    func zeroAndNegativeInput() {
        for raw in [0, -1, -8] {
            for layout in LayoutMode.allCases {
                #expect(
                    BookletLayoutEngine.paddedInputCount(raw, layout: layout, pad: true) == 0,
                    "\(raw) pages with \(layout) should stay empty"
                )
            }
        }
    }
}

// MARK: - Counts

@Suite("BookletLayoutEngine / counts")
struct BookletLayoutEngineCountTests {
    @Test("output sides are half the padded input, rounded up")
    func outputSideCount() {
        #expect(BookletLayoutEngine.outputSideCount(forPaddedInputCount: 4) == 2)
        #expect(BookletLayoutEngine.outputSideCount(forPaddedInputCount: 8) == 4)
        #expect(BookletLayoutEngine.outputSideCount(forPaddedInputCount: 0) == 0)
        #expect(BookletLayoutEngine.outputSideCount(forPaddedInputCount: -2) == 0)
        #expect(BookletLayoutEngine.outputSideCount(forPaddedInputCount: 7) == 4)
    }

    @Test("physical sheets are groups of four input pages")
    func physicalSheetCount() {
        #expect(BookletLayoutEngine.physicalSheetCount(forPaddedInputCount: 4) == 1)
        #expect(BookletLayoutEngine.physicalSheetCount(forPaddedInputCount: 8) == 2)
        #expect(BookletLayoutEngine.physicalSheetCount(forPaddedInputCount: 12) == 3)
        #expect(BookletLayoutEngine.physicalSheetCount(forPaddedInputCount: 0) == 0)
        #expect(BookletLayoutEngine.physicalSheetCount(forPaddedInputCount: -4) == 0)
    }

    @Test("signature capacity rounds down to a multiple of four with a floor of four")
    func signatureCapacityNormalization() {
        #expect(BookletLayoutEngine.signatureCount(inputPageCount: 10, pagesPerSignature: 8) == 2)
        #expect(BookletLayoutEngine.signatureCount(inputPageCount: 8, pagesPerSignature: 8) == 1)
        #expect(BookletLayoutEngine.signatureCount(inputPageCount: 1, pagesPerSignature: 8) == 1)
        // 6 is not a multiple of 4, so it is reduced to 4.
        #expect(BookletLayoutEngine.signatureCount(inputPageCount: 5, pagesPerSignature: 6) == 2)
        // Anything below 4 collapses to the 4-page minimum.
        #expect(BookletLayoutEngine.signatureCount(inputPageCount: 5, pagesPerSignature: 1) == 2)
        #expect(BookletLayoutEngine.signatureCount(inputPageCount: 0, pagesPerSignature: 8) == 0)
    }
}

// MARK: - Page mapping

@Suite("BookletLayoutEngine / page mapping")
struct BookletLayoutEngineMappingTests {
    @Test("booklet fold mapping walks the sheet in print order")
    func bookletFoldMapping() {
        // One sheet of 4 pages: front is [4 | 1], back is [2 | 3].
        #expect(
            BookletLayoutEngine.bookletFoldMapping(outputIndex: 0, paddedInputCount: 4)
                == (left: 4, right: 1)
        )
        #expect(
            BookletLayoutEngine.bookletFoldMapping(outputIndex: 1, paddedInputCount: 4)
                == (left: 2, right: 3)
        )
        // An 8-page booklet: sheet one [8 | 1] / [2 | 7],
        // sheet two [6 | 3] / [4 | 5].
        #expect(
            BookletLayoutEngine.bookletFoldMapping(outputIndex: 0, paddedInputCount: 8)
                == (left: 8, right: 1)
        )
        #expect(
            BookletLayoutEngine.bookletFoldMapping(outputIndex: 1, paddedInputCount: 8)
                == (left: 2, right: 7)
        )
        #expect(
            BookletLayoutEngine.bookletFoldMapping(outputIndex: 2, paddedInputCount: 8)
                == (left: 6, right: 3)
        )
        #expect(
            BookletLayoutEngine.bookletFoldMapping(outputIndex: 3, paddedInputCount: 8)
                == (left: 4, right: 5)
        )
    }

    @Test("booklet fold mapping covers every padded page exactly once")
    func bookletFoldMappingIsAPermutation() {
        for count in stride(from: 4, through: 40, by: 4) {
            let sides = BookletLayoutEngine.outputSideCount(forPaddedInputCount: count)
            var seen: [Int] = []
            for index in 0..<sides {
                let pair = BookletLayoutEngine.bookletFoldMapping(
                    outputIndex: index, paddedInputCount: count
                )
                seen.append(pair.left)
                seen.append(pair.right)
            }
            #expect(
                seen.sorted() == Array(1...count),
                "\(count) pages mapped to \(seen.sorted())"
            )
        }
    }

    @Test("simple pair mapping marks missing pages with zero")
    func simplePairMapping() {
        #expect(
            BookletLayoutEngine.simplePairMapping(outputIndex: 0, paddedInputCount: 4)
                == (left: 1, right: 2)
        )
        #expect(
            BookletLayoutEngine.simplePairMapping(outputIndex: 1, paddedInputCount: 4)
                == (left: 3, right: 4)
        )
        // Odd count: the trailing page has no partner.
        #expect(
            BookletLayoutEngine.simplePairMapping(outputIndex: 1, paddedInputCount: 3)
                == (left: 3, right: 0)
        )
        #expect(
            BookletLayoutEngine.simplePairMapping(outputIndex: 2, paddedInputCount: 3)
                == (left: 0, right: 0)
        )
    }
}

// MARK: - Output sides

@Suite("BookletLayoutEngine / output sides")
struct BookletLayoutEngineOutputSideTests {
    @Test("a four page booklet produces one sheet with both sides")
    func fourPageBooklet() {
        let settings = BookletSettings(layout: .bookletFold)
        let sides = BookletLayoutEngine.buildOutputSides(inputPageCount: 4, settings: settings)

        #expect(sides.count == 2)
        #expect(sides.map(\.index) == [0, 1])
        #expect(sides.map(\.side) == [.front, .back])
        #expect(sides.map(\.physicalSheetIndex) == [0, 0])
        #expect(sides.map(\.sheetIndexInSignature) == [0, 0])
        #expect(sides.map(\.signatureIndex) == [0, 0])
        #expect(sides.map(\.leftPage) == [4, 2])
        #expect(sides.map(\.rightPage) == [1, 3])
    }

    @Test("a padded slot that the source does not have renders as a blank")
    func oddInputLeavesPaddedSlotsBlank() {
        let settings = BookletSettings(layout: .bookletFold)
        let sides = BookletLayoutEngine.buildOutputSides(inputPageCount: 3, settings: settings)

        #expect(sides.count == 2)
        // The sheet front maps to padded [4 | 1]; page 4 is absent from a
        // 3-page source, so its slot is blanked out.
        #expect(sides.map(\.leftPage) == [0, 2])
        #expect(sides.map(\.rightPage) == [1, 3])
    }

    @Test("every real page still appears exactly once after padding")
    func paddedPagesAppearOnce() {
        for pageCount in [1, 2, 3, 5, 6, 7] {
            let settings = BookletSettings(layout: .bookletFold)
            let sides = BookletLayoutEngine.buildOutputSides(
                inputPageCount: pageCount, settings: settings
            )
            let printed = sides.flatMap { [$0.leftPage, $0.rightPage] }.filter { $0 > 0 }
            #expect(
                printed.sorted() == Array(1...pageCount),
                "\(pageCount) pages produced \(printed.sorted())"
            )
        }
    }

    @Test("turning padding off truncates a simple pair layout")
    func simplePairWithoutPadding() {
        let settings = BookletSettings(layout: .simplePair, padBlankPage: false)
        let sides = BookletLayoutEngine.buildOutputSides(inputPageCount: 3, settings: settings)

        #expect(sides.count == 2)
        #expect(sides.map(\.side) == [.front, .front])
        #expect(sides.map(\.leftPage) == [1, 3])
        #expect(sides.map(\.rightPage) == [2, 0])
    }

    @Test("simple pair with padding reserves a partner for the trailing page")
    func simplePairWithPadding() {
        let settings = BookletSettings(layout: .simplePair, padBlankPage: true)
        let sides = BookletLayoutEngine.buildOutputSides(inputPageCount: 3, settings: settings)

        #expect(sides.count == 2)
        #expect(sides.map(\.leftPage) == [1, 3])
        // Page 4 is the padding partner and is blanked for the same reason.
        #expect(sides.map(\.rightPage) == [2, 0])
    }

    @Test("no input produces no output sides")
    func emptyInput() {
        for layout in LayoutMode.allCases {
            let settings = BookletSettings(layout: layout)
            #expect(
                BookletLayoutEngine.buildOutputSides(inputPageCount: 0, settings: settings).isEmpty
            )
        }
    }

    @Test("signature fold keeps every page once across signatures")
    func signatureFoldPagesAreComplete() {
        let settings = BookletSettings(layout: .signatureFold, signaturePageCount: 8)
        let sides = BookletLayoutEngine.buildOutputSides(inputPageCount: 10, settings: settings)

        let printed = sides.flatMap { [$0.leftPage, $0.rightPage] }.filter { $0 > 0 }
        #expect(printed.sorted() == Array(1...10))
        // 8 padded pages → 2 sheets, trailing 2 padded to 4 → 1 sheet.
        #expect(sides.count == 6)
        #expect(sides.map(\.physicalSheetIndex) == [0, 0, 1, 1, 2, 2])
        #expect(Set(sides.map(\.signatureIndex)) == [0, 1])
    }

    @Test("sheet indices restart inside each signature")
    func signatureFoldSheetIndexRestartsPerSignature() {
        let settings = BookletSettings(layout: .signatureFold, signaturePageCount: 4)
        let sides = BookletLayoutEngine.buildOutputSides(inputPageCount: 9, settings: settings)

        #expect(Set(sides.map(\.signatureIndex)) == [0, 1, 2])
        for signature in Set(sides.map(\.signatureIndex)) {
            let inSignature = sides.filter { $0.signatureIndex == signature }
            let sheets = inSignature.count / 2
            let indices = Set(inSignature.map(\.sheetIndexInSignature))
            #expect(
                indices == Set(0..<sheets),
                "signature \(signature) has \(sheets) sheets but indices \(indices.sorted())"
            )
            // Physical sheet indices stay globally unique and monotonic.
            #expect(inSignature.map(\.physicalSheetIndex) == Array(
                repeating: inSignature[0].physicalSheetIndex, count: inSignature.count
            ))
        }
    }

    @Test("signature fold always emits paired front and back sides")
    func signatureFoldSidesArePaired() {
        let settings = BookletSettings(layout: .signatureFold, signaturePageCount: 12)
        let sides = BookletLayoutEngine.buildOutputSides(inputPageCount: 20, settings: settings)

        #expect(sides.count % 2 == 0)
        for offset in stride(from: 0, to: sides.count, by: 2) {
            let front = sides[offset]
            let back = sides[offset + 1]
            #expect(front.side == .front)
            #expect(back.side == .back)
            #expect(back.index == front.index + 1)
            #expect(back.physicalSheetIndex == front.physicalSheetIndex)
        }
    }

    @Test("output side indices are dense and ordered")
    func outputSideIndicesAreDense() {
        for layout in LayoutMode.allCases {
            for pageCount in [1, 3, 4, 9, 20] {
                let settings = BookletSettings(layout: layout, signaturePageCount: 8)
                let sides = BookletLayoutEngine.buildOutputSides(
                    inputPageCount: pageCount, settings: settings
                )
                #expect(
                    sides.map(\.index) == Array(0..<sides.count),
                    "\(layout) with \(pageCount) pages has sparse indices"
                )
            }
        }
    }
}

// MARK: - Physical sheets

@Suite("BookletLayoutEngine / physical sheets")
struct BookletLayoutEnginePhysicalSheetTests {
    @Test("sides group into sheets that each keep one front and optional back")
    func sheetsGroupSides() {
        let settings = BookletSettings(layout: .bookletFold)
        let sheets = BookletLayoutEngine.buildPhysicalSheets(
            inputPageCount: 8, settings: settings
        )

        #expect(sheets.count == 2)
        #expect(sheets.map(\.index) == [0, 1])
        #expect(sheets[0].front.leftPage == 8)
        #expect(sheets[0].front.rightPage == 1)
        #expect(sheets[0].back?.leftPage == 2)
        #expect(sheets[0].back?.rightPage == 7)
        #expect(sheets[1].front.leftPage == 6)
        #expect(sheets[1].front.rightPage == 3)
        #expect(sheets[1].back?.leftPage == 4)
        #expect(sheets[1].back?.rightPage == 5)
        #expect(sheets[0].outputSides.count == 2)
    }

    @Test("simple pair produces front-only sheets")
    func simplePairSheetsAreFrontOnly() {
        let settings = BookletSettings(layout: .simplePair, padBlankPage: true)
        let sheets = BookletLayoutEngine.buildPhysicalSheets(
            inputPageCount: 6, settings: settings
        )

        #expect(sheets.count == 3)
        #expect(sheets.allSatisfy { $0.back == nil })
        #expect(sheets.allSatisfy { $0.outputSides.count == 1 })
        #expect(sheets.map(\.sheetIndexInSignature) == [0, 1, 2])
    }

    @Test("no input produces no sheets")
    func emptyInputHasNoSheets() {
        for layout in LayoutMode.allCases {
            let settings = BookletSettings(layout: layout)
            #expect(
                BookletLayoutEngine.buildPhysicalSheets(inputPageCount: 0, settings: settings).isEmpty
            )
        }
    }

    @Test("sheets and sides agree on the page count of the same layout")
    func sheetsMatchSideCount() {
        for layout in LayoutMode.allCases {
            for pageCount in [1, 3, 4, 7, 12] {
                let settings = BookletSettings(layout: layout, signaturePageCount: 8)
                let sides = BookletLayoutEngine.buildOutputSides(
                    inputPageCount: pageCount, settings: settings
                )
                let sheets = BookletLayoutEngine.buildPhysicalSheets(
                    inputPageCount: pageCount, settings: settings
                )
                #expect(
                    sides.count == sheets.reduce(0) { $0 + $1.outputSides.count },
                    "\(layout) with \(pageCount) pages"
                )
            }
        }
    }

    @Test("a blank helper produces a side with no page references")
    func blankSide() {
        let blank = OutputSheet.blank(index: 3, physicalSheetIndex: 1, side: .back)

        #expect(blank.index == 3)
        #expect(blank.physicalSheetIndex == 1)
        #expect(blank.side == .back)
        #expect(blank.leftPage == 0)
        #expect(blank.rightPage == 0)
    }
}

// MARK: - Geometry

@Suite("BookletLayoutEngine / geometry")
struct BookletLayoutEngineGeometryTests {
    /// `PaperSize.mmToPt` and the cell math mix `Double` and `CGFloat`;
    /// compare geometry with a tolerance rather than exact equality.
    private func expectClose(
        _ actual: CGFloat,
        _ expected: CGFloat,
        _ tolerance: CGFloat = 0.001,
        _ message: Comment? = nil
    ) {
        #expect(abs(actual - expected) < tolerance, message ?? "")
    }

    @Test("fitRect letterboxes a wide page inside a square target")
    func fitRectWidePage() {
        let target = CGRect(x: 0, y: 0, width: 100, height: 100)
        let fitted = BookletLayoutEngine.fitRect(aspectRatio: 2, into: target)

        expectClose(fitted.width, 100)
        expectClose(fitted.height, 50)
        expectClose(fitted.midY, target.midY)
    }

    @Test("fitRect pillarboxes a tall page inside a square target")
    func fitRectTallPage() {
        let target = CGRect(x: 0, y: 0, width: 100, height: 100)
        let fitted = BookletLayoutEngine.fitRect(aspectRatio: 0.5, into: target)

        expectClose(fitted.width, 50)
        expectClose(fitted.height, 100)
        expectClose(fitted.midX, target.midX)
    }

    @Test("fitRect always stays inside the target and keeps the aspect ratio")
    func fitRectStaysInside() {
        let target = CGRect(x: 20, y: 30, width: 300, height: 200)
        for ratio in [CGFloat(0.1), 0.5, 1, 1.414, 3, 10] {
            let fitted = BookletLayoutEngine.fitRect(aspectRatio: ratio, into: target)
            #expect(
                fitted.minX >= target.minX && fitted.maxX <= target.maxX
                    && fitted.minY >= target.minY && fitted.maxY <= target.maxY,
                "ratio \(ratio) produced \(fitted) outside \(target)"
            )
            expectClose(
                fitted.width / fitted.height,
                ratio,
                0.001,
                "ratio \(ratio) was not preserved"
            )
        }
    }

    @Test("fitRect returns the target unchanged for degenerate input")
    func fitRectDegenerate() {
        let target = CGRect(x: 0, y: 0, width: 200, height: 100)
        #expect(BookletLayoutEngine.fitRect(aspectRatio: 0, into: target) == target)
        #expect(BookletLayoutEngine.fitRect(aspectRatio: -1, into: target) == target)
        #expect(BookletLayoutEngine.fitRect(aspectRatio: 1, into: .zero) == .zero)
    }

    @Test("left and right cells sit side by side with the configured gutter")
    func cellRects() {
        let settings = BookletSettings(outputPaper: .a4, marginMM: 5, gutterMM: 5)
        let left = BookletLayoutEngine.leftRect(for: settings)
        let right = BookletLayoutEngine.rightRect(for: settings)

        let margin = CGFloat(PaperSize.mmToPt(5))
        let gutter = CGFloat(PaperSize.mmToPt(5))
        expectClose(left.minX, margin)
        expectClose(left.minY, margin)
        expectClose(right.minX, left.maxX + gutter)
        expectClose(right.minY, margin)
        #expect(left.size == right.size)
        expectClose(left.height, settings.cellHeightInPoints())
    }

    @Test("wider gutters push the right cell further right without resizing height")
    func gutterWidensGap() {
        let narrow = BookletSettings(marginMM: 5, gutterMM: 2)
        let wide = BookletSettings(marginMM: 5, gutterMM: 10)

        #expect(
            BookletLayoutEngine.rightRect(for: wide).minX
                > BookletLayoutEngine.rightRect(for: narrow).minX
        )
        #expect(
            wide.cellWidthInPoints() < narrow.cellWidthInPoints(),
            "a wider gutter must narrow the cells"
        )
        expectClose(wide.cellHeightInPoints(), narrow.cellHeightInPoints())
    }

    @Test("paper display size fits a portrait sheet into the available bounds")
    func paperDisplaySize() {
        let bounds = CGSize(width: 200, height: 200)
        let portrait = BookletLayoutEngine.paperDisplaySize(paper: .a4, within: bounds)
        // A4 is taller than wide, so height is the limiting dimension.
        expectClose(portrait.height, 200)
        expectClose(portrait.width, 200 * 210.0 / 297.0)

        // A wide bounds still caps the sheet at the paper aspect ratio.
        let wideBounds = CGSize(width: 1000, height: 200)
        let wide = BookletLayoutEngine.paperDisplaySize(paper: .a4, within: wideBounds)
        expectClose(wide.height, 200)
        expectClose(wide.width, 200 * 210.0 / 297.0)
    }

    @Test("landscape paper display size mirrors the portrait result")
    func landscapePaperDisplaySize() {
        let bounds = CGSize(width: 400, height: 400)
        let landscape = BookletLayoutEngine.landscapePaperDisplaySize(paper: .a4, within: bounds)
        // Rotated, A4 is wider than tall, so width is the limiting dimension.
        expectClose(landscape.width, 400)
        expectClose(landscape.height, 400 * 210.0 / 297.0)

        let tall = CGSize(width: 100, height: 400)
        let fitted = BookletLayoutEngine.landscapePaperDisplaySize(paper: .a4, within: tall)
        expectClose(fitted.width, 100)
        expectClose(fitted.height, 100 * 210.0 / 297.0)
    }

    @Test("degenerate bounds are returned untouched")
    func paperDisplaySizeDegenerate() {
        #expect(BookletLayoutEngine.paperDisplaySize(paper: .a4, within: .zero) == .zero)
        #expect(
            BookletLayoutEngine.landscapePaperDisplaySize(paper: .a4, within: .zero) == .zero
        )
        let zeroWidth = CGSize(width: 0, height: 400)
        #expect(BookletLayoutEngine.paperDisplaySize(paper: .a4, within: zeroWidth) == zeroWidth)
    }

    @Test("display unit converts a rendered width back into millimetres")
    func displayUnit() {
        // The unit is `width / paper.heightMM`, so feeding a paper's own
        // height in millimetres must yield exactly 1.
        for paper in PaperSize.allCases {
            let unit = BookletLayoutEngine.displayUnit(
                for: CGFloat(paper.heightMM), paper: paper
            )
            expectClose(unit, 1, 0.0001, "\(paper.displayName) should give a unit of 1")
        }

        // Rendering an A4 sheet at its true width in points gives points per mm.
        let pointsWide = CGFloat(PaperSize.mmToPt(PaperSize.a4.widthMM))
        expectClose(
            BookletLayoutEngine.displayUnit(for: pointsWide, paper: .a4),
            pointsWide / 297,
            0.0001
        )
    }
}

// MARK: - Settings geometry

@Suite("BookletSettings")
struct BookletSettingsTests {
    @Test("default settings describe an A4 booklet fold")
    func defaults() {
        let settings = BookletSettings()
        #expect(settings.outputPaper == .a4)
        #expect(settings.layout == .bookletFold)
        #expect(settings.signaturePageCount == 4)
        #expect(settings.readingOrder == .leftToRight)
        #expect(settings.marginMM == 5)
        #expect(settings.gutterMM == 5)
        #expect(settings.padBlankPage)
        #expect(settings.addCutMarks)
    }

    @Test("cell size derives from the paper width, margins and gutter")
    func cellSize() {
        let settings = BookletSettings(outputPaper: .a4, marginMM: 10, gutterMM: 6)
        let paperWidth = PaperSize.mmToPt(297)
        let expectedWidth = (paperWidth - 2 * PaperSize.mmToPt(10) - PaperSize.mmToPt(6)) / 2
        #expect(abs(settings.cellWidthInPoints() - expectedWidth) < 0.001)
        #expect(settings.cellHeightInPoints() > settings.cellWidthInPoints())
    }

    @Test("cells never overlap regardless of margin and gutter")
    func cellsDoNotOverlap() {
        for margin in [0.0, 5.0, 20.0] {
            for gutter in [0.0, 5.0, 30.0] {
                let settings = BookletSettings(marginMM: margin, gutterMM: gutter)
                let left = BookletLayoutEngine.leftRect(for: settings)
                let right = BookletLayoutEngine.rightRect(for: settings)
                #expect(
                    left.maxX <= right.minX + 0.001,
                    "margin \(margin) gutter \(gutter) made cells overlap"
                )
            }
        }
    }

    @Test("settings survive a Codable round trip")
    func codableRoundTrip() throws {
        var settings = BookletSettings()
        settings.layout = .signatureFold
        settings.signaturePageCount = 12
        settings.marginMM = 7.5
        settings.addCutMarks = false

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(BookletSettings.self, from: data)

        #expect(restored == settings)
    }

    @Test("every offered signature size is a usable multiple of four")
    func signaturePageCountOptions() {
        for option in BookletSettings.signaturePageCountOptions {
            #expect(option % 4 == 0, "signature size \(option) is not a multiple of 4")
            #expect(option >= 4)
        }
    }
}

// MARK: - Paper size

@Suite("PaperSize")
struct PaperSizeTests {
    @Test("each paper exposes its standard millimetre dimensions")
    func dimensions() {
        #expect(PaperSize.a4.widthMM == 210)
        #expect(PaperSize.a4.heightMM == 297)
        #expect(PaperSize.a5.widthMM == 148)
        #expect(PaperSize.a5.heightMM == 210)
        #expect(PaperSize.letter.widthMM == 215.9)
        #expect(PaperSize.letter.heightMM == 279.4)
    }

    @Test("every paper is taller than it is wide in portrait")
    func portraitPapers() {
        for paper in PaperSize.allCases {
            #expect(paper.heightMM > paper.widthMM, "\(paper.displayName) is not portrait")
            #expect(paper.widthMM > 0)
        }
    }

    @Test("millimetre and point conversion round trips")
    func unitRoundTrip() {
        for millimetres in [1.0, 10.0, 148.0, 210.0, 297.0] {
            let points = PaperSize.mmToPt(millimetres)
            #expect(abs(PaperSize.ptToMM(points) - millimetres) < 0.0001)
        }
        #expect(abs(PaperSize.mmToPt(25.4) - 72) < 0.0001)
    }

    @Test("point sizes swap width and height in landscape")
    func sizeInPoints() {
        for paper in PaperSize.allCases {
            let portrait = paper.sizeInPoints
            let landscape = paper.landscapeSizeInPoints
            #expect(abs(portrait.width - landscape.height) < 0.001)
            #expect(abs(portrait.height - landscape.width) < 0.001)
        }
    }

    @Test("papers have distinct stable identifiers and display names")
    func identity() {
        #expect(PaperSize.allCases.count == 3)
        #expect(Set(PaperSize.allCases.map(\.rawValue)).count == 3)
        for paper in PaperSize.allCases {
            #expect(paper.id == paper.rawValue)
            #expect(!paper.displayName.isEmpty)
        }
        #expect(PaperSize.allCases.map(\.displayName) == ["A4", "A5", "Letter"])
    }

    @Test("papers survive a Codable round trip by raw value")
    func codableRoundTrip() throws {
        for paper in PaperSize.allCases {
            let data = try JSONEncoder().encode(paper)
            #expect(String(data: data, encoding: .utf8) == "\"\(paper.rawValue)\"")
            #expect(try JSONDecoder().decode(PaperSize.self, from: data) == paper)
        }
    }
}

// MARK: - Layout mode

@Suite("LayoutMode")
struct LayoutModeTests {
    @Test("every layout is a folded layout except simple pair")
    func isFolded() {
        #expect(LayoutMode.bookletFold.isFolded)
        #expect(LayoutMode.signatureFold.isFolded)
        #expect(!LayoutMode.simplePair.isFolded)
    }

    @Test("every layout has a non-empty display name")
    func displayNames() {
        let names = LayoutMode.allCases.map(\.displayName)
        #expect(names.count == 3)
        #expect(Set(names).count == 3, "layout display names must be distinct")
        #expect(names.allSatisfy { !$0.isEmpty })
    }

    @Test("layouts survive a Codable round trip")
    func codableRoundTrip() throws {
        for layout in LayoutMode.allCases {
            let data = try JSONEncoder().encode(layout)
            #expect(try JSONDecoder().decode(LayoutMode.self, from: data) == layout)
            #expect(layout.id == layout.rawValue)
        }
    }

    @Test("reading order has a stable single case")
    func readingOrder() {
        #expect(ReadingOrder.allCases == [.leftToRight])
        #expect(ReadingOrder.leftToRight.id == "leftToRight")
    }
}
