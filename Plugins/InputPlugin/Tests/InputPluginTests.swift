#if canImport(XCTest)
import XCTest
@testable import Lumi

class InputPluginTests: XCTestCase {
    
    func testInputRuleCodable() {
        let rule = InputRule(appBundleID: "com.test.app", appName: "Test App", inputSourceID: "com.apple.keylayout.US")
        
        do {
            let data = try JSONEncoder().encode(rule)
            let decoded = try JSONDecoder().decode(InputRule.self, from: data)
            
            XCTAssertEqual(rule.appBundleID, decoded.appBundleID)
            XCTAssertEqual(rule.inputSourceID, decoded.inputSourceID)
        } catch {
            XCTFail("Codable failed: \(error)")
        }
    }
    
    func testInputConfigDefaults() {
        let config = InputConfig()
        XCTAssertTrue(config.isEnabled)
        XCTAssertTrue(config.rules.isEmpty)
        XCTAssertNil(config.defaultInputSourceID)
    }
    
    @MainActor
    func testInputServiceSingleton() {
        let service = InputService.shared
        XCTAssertNotNil(service)
    }
}
#endif

