import XCTest
import XcodeProj
import PathKit
@testable import XcodeKit

final class PBXProjWriteSupportTests: XCTestCase {
    func testWriteProjectWithPathOnlyProjectReferenceDoesNotCrash() throws {
        let fixturePath = Path(
            "/Users/angel/Code/Coffic/Lumi/Packages/XcodeKit/.build/checkouts/XcodeProj/Fixtures/Xcode16ProjectReferenceOrder/Wrong.xcodeproj"
        )
        guard fixturePath.exists else {
            throw XCTSkip("XcodeProj fixture is unavailable")
        }

        let tempRoot = Path(NSTemporaryDirectory()) + "xcodekit-write-support-\(UUID().uuidString)"
        let tempProjectPath = tempRoot + "Wrong.xcodeproj"
        defer { try? tempRoot.delete() }

        try tempRoot.mkpath()
        try FileManager.default.copyItem(atPath: fixturePath.string, toPath: tempProjectPath.string)

        let xcodeProj = try XcodeProj(path: tempProjectPath)
        for fileReference in xcodeProj.pbxproj.fileReferences where fileReference.path?.hasSuffix(".xcodeproj") == true {
            fileReference.name = nil
        }

        let outputPath = tempRoot + "Output.xcodeproj"
        try FileManager.default.copyItem(atPath: tempProjectPath.string, toPath: outputPath.string)

        let outputProj = try XcodeProj(path: outputPath)
        for fileReference in outputProj.pbxproj.fileReferences where fileReference.path?.hasSuffix(".xcodeproj") == true {
            fileReference.name = nil
        }

        XCTAssertNoThrow(try PBXProjWriteSupport.write(outputProj, pathString: outputPath.string, override: true))
    }
}
