import Foundation
import Testing
@testable import LumiCoreKit

@Test func pendingMarkerDetection() {
    let pending = """
    \(LumiAskUserMarkers.pendingPrefix)
    {"question":"Continue?"}
    """

    #expect(LumiAskUserMarkers.isPendingResponse(pending))
    #expect(LumiAskUserMarkers.isPendingResponse("Yes") == false)
}
