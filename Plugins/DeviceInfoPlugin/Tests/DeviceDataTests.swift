import Foundation
import Testing
@testable import DeviceInfoPlugin

struct DeviceDataTests {
    @Test func physicalCoreCountIsPositiveAndNotGreaterThanLogicalCores() {
        let physical = DeviceData.physicalCoreCount()
        let logical = ProcessInfo.processInfo.activeProcessorCount

        #expect(physical > 0)
        #expect(physical <= logical)
    }
}
