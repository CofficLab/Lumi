import Testing
import KitShell
@testable import PortManagerPlugin

// 回归 #258：lsof 输出超过 KitShell 捕获上限时只保留尾部，
// 必须显式报 outputTruncated，不能把截尾当完整监听列表而静默丢端口。

private let sampleLsofOutput = """
COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    12345 user   21u  IPv4 0x123456789abcdef0      0t0  TCP *:3000 (LISTEN)
"""

@Test func scanThrowsWhenOutputTruncated() {
    let result = ShellResult(exitCode: 0, stdout: sampleLsofOutput, stderr: "", stdoutTruncated: true)
    do {
        _ = try PortScanner.shared.interpretScanResult(result)
        Issue.record("expected outputTruncated")
    } catch PortScannerError.outputTruncated {
        #expect(PortScannerError.outputTruncated.errorDescription?.isEmpty == false)
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}

@Test func scanReturnsPortsWhenOutputComplete() throws {
    let result = ShellResult(exitCode: 0, stdout: sampleLsofOutput, stderr: "", stdoutTruncated: false)
    let ports = try PortScanner.shared.interpretScanResult(result)
    #expect(ports.count == 1)
    #expect(ports[0].command == "node")
    #expect(ports[0].port == "3000")
}

@Test func scanThrowsOnSignalExitThroughSeam() {
    let result = ShellResult(exitCode: 15, stdout: "", stderr: "", stdoutTruncated: false)
    #expect(throws: PortScannerError.self) {
        try PortScanner.shared.interpretScanResult(result)
    }
}