import XCTest
@testable import KitWebServer

/// StartGate 终态投递回归（#201）：performStart 的 runTask 先于 arm 启动，
/// succeed/fail 可能早于 arm 到达；早到的终态必须被缓存并在 arm 时立即投递，
/// 否则 withCheckedThrowingContinuation 永久挂起，start() 不返回也不抛错。
final class StartGateTests: XCTestCase {
    /// 线程安全结果盒：arm 在游离 Task 中投递，测试侧轮询读取。
    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Int, any Error>?
        func store(_ value: Result<Int, any Error>) {
            lock.lock(); result = value; lock.unlock()
        }
        func take() -> Result<Int, any Error>? {
            lock.lock(); defer { lock.unlock() }; return result
        }
    }

    /// 在游离 Task 中 arm 并等待投递，用轮询+超时避免缺陷代码挂死整个套件。
    /// 返回 nil 表示超时（gate 未投递终态）。
    private func deliver(_ gate: StartGate, timeout: TimeInterval = 2) async -> Result<Int, any Error>? {
        let box = ResultBox()
        Task {
            do {
                let port = try await withCheckedThrowingContinuation { gate.arm($0) }
                box.store(.success(port))
            } catch {
                box.store(.failure(error))
            }
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let result = box.take() { return result }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return nil
    }

    func testEarlySuccessIsDeliveredWhenArmed() async throws {
        let gate = StartGate()
        gate.succeed(withPort: 8080)   // 终态早于 arm
        let result = await deliver(gate)
        let port = try XCTUnwrap(result, "gate 挂起：早到的成功被丢弃").get()
        XCTAssertEqual(port, 8080)
    }

    func testEarlyFailureIsDeliveredWhenArmed() async {
        let gate = StartGate()
        let injected = NSError(domain: "StartGateTest", code: 42)
        gate.fail(injected)   // 终态早于 arm
        guard let result = await deliver(gate) else {
            return XCTFail("gate 挂起：早到的失败被丢弃")
        }
        switch result {
        case .success:
            XCTFail("应当投递失败")
        case .failure(let error as NSError):
            XCTAssertEqual(error.domain, "StartGateTest")
            XCTAssertEqual(error.code, 42)
        case .failure(let error):
            XCTFail("非预期错误：\(error)")
        }
    }

    func testOnlyFirstTerminalStateIsDelivered() async throws {
        let gate = StartGate()
        gate.succeed(withPort: 1111)
        gate.fail(NSError(domain: "late", code: 1))   // 第二个终态必须被忽略
        let result = await deliver(gate)
        let port = try XCTUnwrap(result, "gate 挂起").get()
        XCTAssertEqual(port, 1111)
    }

    func testSuccessAfterArmIsDelivered() async throws {
        let gate = StartGate()
        // 正常路径：arm 先安装 continuation，再发信号。
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            gate.succeed(withPort: 9090)
        }
        let result = await deliver(gate)
        let port = try XCTUnwrap(result, "gate 挂起").get()
        XCTAssertEqual(port, 9090)
    }
}