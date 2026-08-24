import Testing
import Foundation
@testable import AppStoreConnectPlugin

/// Unit tests for the pure-logic version-string helpers and platform/sidebar
/// normalization in `AppStoreVersion`.
@Suite struct VersionStringValidatorTests {

    @Test func isValidAcceptsNumericDottedVersions() {
        #expect(VersionStringValidator.isValid("1.0.0"))
        #expect(VersionStringValidator.isValid("1"))
        #expect(VersionStringValidator.isValid("1.2"))
        #expect(VersionStringValidator.isValid("1.2.3.4"))
        #expect(VersionStringValidator.isValid(" 1.2.3 "))
    }

    @Test func isValidRejectsEmptyAndWhitespace() {
        #expect(!VersionStringValidator.isValid(""))
        #expect(!VersionStringValidator.isValid("   "))
    }

    @Test func isValidRejectsNonNumeric() {
        #expect(!VersionStringValidator.isValid("1.0.x"))
        #expect(!VersionStringValidator.isValid("v1.0.0"))
        #expect(!VersionStringValidator.isValid("1.0.0-beta"))
        #expect(!VersionStringValidator.isValid("1..0"))
    }

    @Test func isValidRejectsOverLength() {
        #expect(!VersionStringValidator.isValid(String(repeating: "1", count: 65)))
    }

    @Test func normalizedTrimsWhitespace() {
        #expect(VersionStringValidator.normalized("  1.2.3  ") == "1.2.3")
    }
}

@Suite struct AppStoreVersionCompareTests {

    @Test func compareOrdersNumerically() {
        #expect(AppStoreVersion.compareVersionStrings("1.0.0", "2.0.0") == .orderedAscending)
        #expect(AppStoreVersion.compareVersionStrings("2.0.0", "1.0.0") == .orderedDescending)
        #expect(AppStoreVersion.compareVersionStrings("1.0.0", "1.0.0") == .orderedSame)
    }

    @Test func compareHandlesDifferentSegmentCounts() {
        // 1.0 vs 1.0.0 → treat missing segment as 0 → equal-ish then 1.0.0 not greater
        #expect(AppStoreVersion.compareVersionStrings("1.0", "1.0.0") == .orderedSame)
        #expect(AppStoreVersion.compareVersionStrings("1.0.0", "1.0.1") == .orderedAscending)
    }

    @Test func compareNumericNotLexicographic() {
        // Lexicographically "10" < "9", but numerically 10 > 9.
        #expect(AppStoreVersion.compareVersionStrings("1.10.0", "1.9.0") == .orderedDescending)
    }

    @Test func compareIgnoresNonNumericSegments() {
        // Non-numeric segments become nil → compactMap drops them.
        #expect(AppStoreVersion.compareVersionStrings("1.0", "1.a") == .orderedSame)
    }
}

@Suite struct AppStoreVersionBumpTests {

    @Test func bumpIncrementsPatch() {
        #expect(AppStoreVersion.bumpPatchVersion("1.2.3") == "1.2.4")
        #expect(AppStoreVersion.bumpPatchVersion("1.0.0") == "1.0.1")
    }

    @Test func bumpHandlesSingleSegment() {
        #expect(AppStoreVersion.bumpPatchVersion("5") == "6")
    }

    @Test func bumpAppendsWhenLastSegmentNonNumeric() {
        // Non-numeric last segment → append "1" instead of incrementing.
        #expect(AppStoreVersion.bumpPatchVersion("1.2.x") == "1.2.x.1")
    }
}

@Suite struct AppStoreVersionPlatformTests {

    @Test func normalizedASCPlatformMapsAliases() {
        #expect("macos".normalizedASCPlatform == "MAC_OS")
        #expect("MAC_OS".normalizedASCPlatform == "MAC_OS")
        #expect("tvos".normalizedASCPlatform == "TV_OS")
        #expect("visionos".normalizedASCPlatform == "VISION_OS")
        #expect("ios".normalizedASCPlatform == "IOS")
    }

    @Test func normalizedASCPlatformPreservesUnknown() {
        #expect("web".normalizedASCPlatform == "WEB")
    }

    @Test func platformOrderIsStable() {
        #expect(AppStoreVersion.platformOrder == ["IOS", "MAC_OS", "TV_OS", "VISION_OS"])
    }
}

@Suite struct AppStoreVersionStateTests {

    private func makeVersion(state: String) -> AppStoreVersion {
        AppStoreVersion(id: "1", platform: "IOS", versionString: "1.0.0",
                        appStoreState: state, appVersionState: "", createdDate: nil)
    }

    @Test func blocksNewVersionCreateForInProgressStates() {
        #expect(makeVersion(state: "PREPARE_FOR_SUBMISSION").blocksNewVersionCreate)
        #expect(makeVersion(state: "WAITING_FOR_REVIEW").blocksNewVersionCreate)
        #expect(makeVersion(state: "IN_REVIEW").blocksNewVersionCreate)
        #expect(makeVersion(state: "DEVELOPER_REJECTED").blocksNewVersionCreate)
    }

    @Test func allowsNewVersionCreateForTerminalStates() {
        #expect(!makeVersion(state: "READY_FOR_SALE").blocksNewVersionCreate)
        // PENDING_DEVELOPER_RELEASE is a terminal, non-blocking state.
        #expect(!makeVersion(state: "PENDING_DEVELOPER_RELEASE").blocksNewVersionCreate)
    }

    @Test func sidebarSortPriorityRanksPrepareHighest() {
        #expect(makeVersion(state: "PREPARE_FOR_SUBMISSION").sidebarSortPriority == 100)
        #expect(makeVersion(state: "READY_FOR_SALE").sidebarSortPriority == 10)
        // Unknown state falls to the default bucket.
        #expect(makeVersion(state: "MYSTERY_STATE").sidebarSortPriority == 50)
    }
}

@Suite struct AppStoreVersionSuggestionTests {

    private func v(_ version: String, _ platform: String = "IOS", _ state: String = "READY_FOR_SALE",
                   _ created: Date? = nil) -> AppStoreVersion {
        AppStoreVersion(id: version + platform, platform: platform, versionString: version,
                        appStoreState: state, appVersionState: "", createdDate: created)
    }

    @Test func suggestedNextBumpsHighestOnPlatform() {
        let versions = [v("1.0.0"), v("1.2.0"), v("1.1.0")]
        #expect(AppStoreVersion.suggestedNextVersionString(for: "IOS", in: versions) == "1.2.1")
    }

    @Test func suggestedNextDefaultsToOneZeroZeroWhenNone() {
        #expect(AppStoreVersion.suggestedNextVersionString(for: "IOS", in: []) == "1.0.0")
    }

    @Test func suggestedNextAvoidsCollisions() {
        let versions = [v("1.0.0"), v("1.0.1")]
        // Highest is 1.0.1 → bump → 1.0.2 (1.0.1 exists so skip)
        #expect(AppStoreVersion.suggestedNextVersionString(for: "IOS", in: versions) == "1.0.2")
    }

    @Test func validateCreateRejectsEmpty() {
        #expect(throws: VersionCreateValidationError.self) {
            _ = try AppStoreVersion.validateCreate(versionString: "  ", platform: "IOS", versions: [])
        }
    }

    @Test func validateCreateRejectsInvalidFormat() {
        #expect(throws: VersionCreateValidationError.self) {
            _ = try AppStoreVersion.validateCreate(versionString: "1.x", platform: "IOS", versions: [])
        }
    }

    @Test func validateCreateRejectsDuplicate() throws {
        let versions = [v("1.0.0")]
        #expect(throws: VersionCreateValidationError.self) {
            _ = try AppStoreVersion.validateCreate(versionString: "1.0.0", platform: "IOS", versions: versions)
        }
    }

    @Test func validateCreateRejectsPlatformInProgress() {
        let versions = [v("1.0.0", "IOS", "PREPARE_FOR_SUBMISSION")]
        #expect(throws: VersionCreateValidationError.self) {
            _ = try AppStoreVersion.validateCreate(versionString: "1.0.1", platform: "IOS", versions: versions)
        }
    }

    @Test func validateCreateNormalizesPlatform() throws {
        let (version, platform) = try AppStoreVersion.validateCreate(
            versionString: "1.0.0", platform: "macos", versions: []
        )
        #expect(version == "1.0.0")
        #expect(platform == "MAC_OS")
    }
}
