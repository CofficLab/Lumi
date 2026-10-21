import Foundation

/// 当前进程是否在跑单元测试。
///
/// ## 为什么不用 `NSClassFromString("XCTestCase")`
///
/// 它在两种运行方式下都为 true，但**无法区分**「测试进程」与「为了承载 UI 测试
/// 而链接了 XCTest 的 Debug App」。UI 测试里的 `Lumi.app` 是正式 App 进程，
/// 误判会让它把数据写进临时目录，等于每条 UI 用例都在用一次性存储跑真实产品，
/// 掩盖真实缺陷。
///
/// ## 两种测试运行方式的进程特征完全不同
///
/// - `xcodebuild test`：主 bundle 就是 `<Name>.xctest`，并注入
///   `XCTestConfigurationFilePath`。
/// - `swift test`（SwiftPM）：主可执行文件是 `xctest` 或
///   `swiftpm-testing-helper`，`Bundle.main` 指向 swiftpm 工具链目录，
///   **不是** `.xctest`，也**不注入** `XCTestConfigurationFilePath`。
///
/// 正式 App 的可执行文件名是 `Lumi` / `LumiACP` / `AppIconDesigner` 等，
/// 与下列判据均不匹配。
public enum TestProcessDetector {

    /// 当前进程是否为单元测试进程。
    public static var isTestProcess: Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        if Bundle.main.bundlePath.hasSuffix(".xctest") {
            return true
        }
        let executable = CommandLine.arguments.first?
            .split(separator: "/").last.map(String.init) ?? ""
        return executable.hasSuffix(".xctest") || executable == "swiftpm-testing-helper"
    }
}