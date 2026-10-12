import XCTest
@testable import KitMail

final class KitMailTests: XCTestCase {
    func testModuleExportsSessionProtocols() {
        // 协议类型的元类型存在即证明导出可用（编译期验证）
        let factory: any MailSessionFactory.Type = MailCoreAdapterFactory.self
        _ = factory
        let session: any MailSessionServing.Type = MockMailSession.self
        _ = session
    }
}
