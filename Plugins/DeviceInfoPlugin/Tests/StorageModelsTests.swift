import Foundation
import Testing
@testable import DeviceInfoPlugin

struct StorageModelsTests {
    @Test
    func volumeInfoUsedCapacity() {
        let volume = VolumeInfo(
            name: "Macintosh HD",
            totalCapacity: 500_000_000_000,
            availableCapacity: 200_000_000_000,
            isInternal: true,
            isEjectable: false,
            url: URL(fileURLWithPath: "/")
        )
        #expect(volume.usedCapacity == 300_000_000_000)
    }

    @Test
    func volumeInfoUsedCapacityClampsToZero() {
        let volume = VolumeInfo(
            name: "Test",
            totalCapacity: 100,
            availableCapacity: 200,
            isInternal: true,
            isEjectable: false,
            url: URL(fileURLWithPath: "/")
        )
        #expect(volume.usedCapacity == 0)
    }

    @Test
    func volumeInfoUsagePercent() {
        let volume = VolumeInfo(
            name: "Test",
            totalCapacity: 1000,
            availableCapacity: 250,
            isInternal: true,
            isEjectable: false,
            url: URL(fileURLWithPath: "/")
        )
        #expect(volume.usagePercent == 75)
    }

    @Test
    func volumeInfoUsagePercentZeroTotal() {
        let volume = VolumeInfo(
            name: "Test",
            totalCapacity: 0,
            availableCapacity: 0,
            isInternal: true,
            isEjectable: false,
            url: URL(fileURLWithPath: "/")
        )
        #expect(volume.usagePercent == 0)
    }

    @Test
    func volumeInfoUsageFraction() {
        let volume = VolumeInfo(
            name: "Test",
            totalCapacity: 1000,
            availableCapacity: 300,
            isInternal: true,
            isEjectable: false,
            url: URL(fileURLWithPath: "/")
        )
        #expect(volume.usageFraction == 0.7)
    }

    @Test
    func volumeInfoUsageFractionZeroTotal() {
        let volume = VolumeInfo(
            name: "Test",
            totalCapacity: 0,
            availableCapacity: 0,
            isInternal: true,
            isEjectable: false,
            url: URL(fileURLWithPath: "/")
        )
        #expect(volume.usageFraction == 0)
    }

    @Test
    func volumeInfoFormattedStrings() {
        let volume = VolumeInfo(
            name: "Test",
            totalCapacity: 1_000_000_000_000,
            availableCapacity: 400_000_000_000,
            isInternal: true,
            isEjectable: false,
            url: URL(fileURLWithPath: "/")
        )
        #expect(!volume.totalString.isEmpty)
        #expect(!volume.usedString.isEmpty)
        #expect(!volume.availableString.isEmpty)
    }

    @Test
    func volumeInfoUniqueIDs() {
        let a = VolumeInfo(name: "A", totalCapacity: 100, availableCapacity: 50, isInternal: true, isEjectable: false, url: URL(fileURLWithPath: "/a"))
        let b = VolumeInfo(name: "A", totalCapacity: 100, availableCapacity: 50, isInternal: true, isEjectable: false, url: URL(fileURLWithPath: "/a"))
        // Each VolumeInfo has a unique auto-generated UUID
        #expect(a.id != b.id)
    }
}
