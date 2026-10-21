import Foundation
import Testing
@testable import KitTestIsolation

@Suite("测试进程判定")
struct TestProcessDetectorTests {

    /// 这是整套隔离机制的地基：判据失效意味着所有目录守卫都会静默放行，
    /// 测试重新开始读写开发者本机真实数据。因此必须显式锁死该行为。
    @Test("在测试进程中判定为真")
    func detectsTestProcess() {
        #expect(TestProcessDetector.isTestProcess)
    }

    /// 记录判定所依据的信号，便于判据失效时定位是哪个特征变了
    /// （例如某次工具链升级改了可执行文件名）。
    @Test("记录判据命中的信号来源")
    func reportsWhichSignalMatched() {
        let environment = ProcessInfo.processInfo.environment
        let bundlePath = Bundle.main.bundlePath
        let executable = CommandLine.arguments.first?
            .split(separator: "/").last.map(String.init) ?? ""

        let signal: String
        if environment["XCTestConfigurationFilePath"] != nil {
            signal = "XCTestConfigurationFilePath"
        } else if bundlePath.hasSuffix(".xctest") {
            signal = "Bundle.main(\(bundlePath))"
        } else {
            signal = "executable(\(executable))"
        }

        print("[TestProcessDetector] 命中信号：\(signal)")
        #expect(TestProcessDetector.isTestProcess)
    }

    @Test("不依赖 XCTestCase 类是否存在")
    func doesNotDependOnXCTestCaseClass() {
        // 该判据在 UI 测试所驱动的 App 进程里同样为真，
        // 用它做隔离会让正式产品在测试中改用临时存储。
        // 这里只做文档性断言：生产守卫不得采用这一判据。
        #expect(TestProcessDetector.isTestProcess)
    }
}