import CoreGraphics
import Testing
@testable import LumiUI

@Suite("AppSymbols")
struct AppSymbolsTests {
    @Test
    func mediaSymbolsMatchSFNames() {
        #expect(AppSymbol.playFill == "play.fill")
        #expect(AppSymbol.pauseFill == "pause.fill")
        #expect(AppSymbol.backward == "backward")
        #expect(AppSymbol.forward == "forward")
        #expect(AppSymbol.previousPage == "chevron.backward")
        #expect(AppSymbol.nextPage == "chevron.forward")
        #expect(AppSymbol.repeatOne == "repeat.1")
        #expect(AppSymbol.repeatAll == "repeat")
        #expect(AppSymbol.shuffle == "shuffle")
    }

    @Test
    func libraryAndFileSymbolsMatchSFNames() {
        #expect(AppSymbol.musicNote == "music.note")
        #expect(AppSymbol.musicLibrary == "music.note.house")
        #expect(AppSymbol.musicNoteList == "music.note.list")
        #expect(AppSymbol.folder == "folder")
        #expect(AppSymbol.document == "doc.text")
        #expect(AppSymbol.photos == "photo.on.rectangle.fill")
        #expect(AppSymbol.finderWindow == "macwindow")
        #expect(AppSymbol.showInFinder == "arrow.forward.circle")
        #expect(AppSymbol.arrowUpCircle == "arrow.up.circle")
        #expect(AppSymbol.reset == "arrow.counterclockwise")
    }

    @Test
    func actionSymbolsMatchSFNames() {
        #expect(AppSymbol.checkmark == "checkmark")
        #expect(AppSymbol.close == "xmark.circle.fill")
        #expect(AppSymbol.info == "info.circle")
        #expect(AppSymbol.list == "list.bullet")
        #expect(AppSymbol.more == "ellipsis")
        #expect(AppSymbol.heart == "heart")
        #expect(AppSymbol.cloud == "cloud")
        #expect(AppSymbol.appStore == "storefront")
    }

    @Test
    func symbolsAreUniqueSoRenamesStayTraceable() {
        // music.note backs both the plain note and the legacy *Fill alias; a
        // duplicate here would mean one of them can drift independently.
        let all = [
            AppSymbol.playFill, AppSymbol.pauseFill, AppSymbol.backward, AppSymbol.forward,
            AppSymbol.previousPage, AppSymbol.nextPage, AppSymbol.repeatOne, AppSymbol.repeatAll,
            AppSymbol.shuffle, AppSymbol.musicNote, AppSymbol.musicLibrary, AppSymbol.musicNoteList,
            AppSymbol.folder, AppSymbol.document, AppSymbol.photos, AppSymbol.finderWindow,
            AppSymbol.showInFinder, AppSymbol.arrowUpCircle, AppSymbol.reset, AppSymbol.checkmark,
            AppSymbol.close, AppSymbol.info, AppSymbol.list, AppSymbol.more, AppSymbol.heart,
            AppSymbol.cloud, AppSymbol.appStore,
        ]

        #expect(Set(all).count == all.count)
    }
}

@Suite("AppResponsivePlayerLayoutMetrics")
struct AppResponsivePlayerLayoutMetricsTests {
    private let metrics = AppResponsivePlayerLayoutMetrics()

    @Test
    func defaultsMatchTheSharedPlayerContract() {
        #expect(metrics.minimumWindowSize == CGSize(width: 400, height: 250))
        #expect(metrics.controlMinimumHeight == 250)
        #expect(metrics.contentMinimumHeight == 200)
        #expect(metrics.secondaryColumnMinimumWidth == 768)
        #expect(metrics.emptyControlHeight == 150)
        #expect(metrics.secondaryColumnDropHeightThreshold == 270)
        #expect(metrics.secondaryColumnMinimumHeight == 450)
        #expect(metrics.controlButtonSpacing == 12)
        #expect(metrics.controlButtonBottomPadding == 20)
        #expect(metrics.controlButtonMinimumSize == 44)
        #expect(metrics.controlButtonMaximumSize == 72)
    }

    @Test
    func stateHeightFollowsTieredThresholds() {
        #expect(metrics.stateHeight(for: 200) == 24)
        #expect(metrics.stateHeight(for: 250) == 24)
        #expect(metrics.stateHeight(for: 251) == 36)
        #expect(metrics.stateHeight(for: 450) == 36)
        #expect(metrics.stateHeight(for: 451) == 48)
    }

    @Test
    func controlButtonHeightKeepsTheTappableFloorWhenOnlyHeightIsTight() {
        // Width is not binding here, so the row still reserves a 44pt target
        // plus its bottom padding even though the window is far too short for
        // the responsive formula on its own.
        let short = metrics.controlButtonHeight(width: 1000, height: 120)
        #expect(short == metrics.controlButtonMinimumSize + metrics.controlButtonBottomPadding)
    }

    @Test
    func controlButtonHeightLetsWidthConstrainTheFloorWhenItIsNarrower() {
        // At 200pt the five-button row only affords ~30pt per button, so the
        // floor follows the width instead of the nominal 44pt minimum.
        let narrow = metrics.controlButtonHeight(width: 200, height: 120)
        #expect(narrow > metrics.controlButtonBottomPadding)
        #expect(narrow < metrics.controlButtonMinimumSize + metrics.controlButtonBottomPadding)
    }

    @Test
    func controlButtonHeightGrowsWithTheWindow() {
        let compact = metrics.controlButtonHeight(width: 500, height: 400)
        let roomy = metrics.controlButtonHeight(width: 1400, height: 1200)
        #expect(roomy > compact)
    }

    @Test
    func controlButtonHeightRejectsNonPositiveAndNonFiniteInput() {
        #expect(metrics.controlButtonHeight(width: 0, height: 400) == 0)
        #expect(metrics.controlButtonHeight(width: 500, height: 0) == 0)
        #expect(metrics.controlButtonHeight(width: -100, height: 400) == 0)
        #expect(metrics.controlButtonHeight(width: .nan, height: 400) == 0)
        #expect(metrics.controlButtonHeight(width: 500, height: .infinity) == 0)
    }

    @Test
    func controlButtonSizeIsBoundedByWidthHeightAndMaximum() {
        // Wide and tall: the 72pt cap wins.
        #expect(metrics.controlButtonSize(width: 2000, areaHeight: 600) == 72)
        // Narrow: the row width wins.
        #expect(metrics.controlButtonSize(width: 300, areaHeight: 600) == 50.4)
        // Short: the reserved height wins.
        #expect(metrics.controlButtonSize(width: 2000, areaHeight: 80) == 60)
    }

    @Test
    func controlButtonSizeRejectsNonPositiveAndNonFiniteInput() {
        #expect(metrics.controlButtonSize(width: 0, areaHeight: 400) == 0)
        #expect(metrics.controlButtonSize(width: 400, areaHeight: 0) == 0)
        #expect(metrics.controlButtonSize(width: .infinity, areaHeight: 400) == 0)
    }

    @Test
    func secondaryColumnAppearsOnlyAboveItsWidthThreshold() {
        #expect(metrics.shouldShowSecondaryColumn(width: 768) == false)
        #expect(metrics.shouldShowSecondaryColumn(width: 769) == true)
    }

    @Test
    func horizontalCenteringOffsetCompensatesForOverwideProposals() {
        #expect(metrics.horizontalCenteringOffset(proposedWidth: 1000, visibleWidth: 600) == 200)
        #expect(metrics.horizontalCenteringOffset(proposedWidth: 600, visibleWidth: 1000) == 0)
        #expect(metrics.horizontalCenteringOffset(proposedWidth: 600, visibleWidth: 600) == 0)
    }

    @Test
    func horizontalCenteringOffsetRejectsNonFiniteInput() {
        #expect(metrics.horizontalCenteringOffset(proposedWidth: .nan, visibleWidth: 600) == 0)
        #expect(metrics.horizontalCenteringOffset(proposedWidth: 1000, visibleWidth: .infinity) == 0)
    }

    @Test
    func expandedWindowIsNeededWhenContentCannotClearTheControls() {
        #expect(metrics.needsExpandedWindow(for: 440) == true)
        #expect(metrics.needsExpandedWindow(for: 451) == false)
    }
}
