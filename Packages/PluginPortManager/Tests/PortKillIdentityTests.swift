import Testing
@testable import PortManagerPlugin

// 回归 #246：确认 kill 前必须复核进程身份（启动时间）与端口归属，
// PID 被复用或进程已退出时拒绝 SIGKILL，不得只凭扫描时的旧 PID 动手。

private let scanStartTime = "Sat Nov 15 10:00:00 2026"

private func listeningPort(pid: String = "12345", port: String = "3000") -> PortInfo {
    PortInfo(
        command: "node",
        pid: pid,
        user: "user",
        protocolName: "TCP",
        port: port,
        address: "*:\(port)"
    )
}

@Test func parsesProcessStartTimesFromPsOutput() {
    let output = """
      12345 Sat Nov 15 10:00:00 2026
      23456 Sun Nov 16 08:30:15 2026
    not-a-pid Sat Nov 15 10:00:00 2026

    """

    let startTimes = PortScanner.parseProcessStartTimes(output)

    #expect(startTimes.count == 2)
    #expect(startTimes["12345"] == scanStartTime)
    #expect(startTimes["23456"] == "Sun Nov 16 08:30:15 2026")
}

@Test func killAllowedWhenIdentityAndPortUnchanged() throws {
    try PortScanner.ensureKillTargetStillValid(
        expectedStartTime: scanStartTime,
        currentStartTime: scanStartTime,
        expectedPort: "3000",
        currentListeningPorts: [listeningPort()]
    )
}

@Test func killRefusedWhenPidReusedByDifferentProcess() {
    do {
        try PortScanner.ensureKillTargetStillValid(
            expectedStartTime: scanStartTime,
            currentStartTime: "Sun Nov 16 09:00:00 2026",
            expectedPort: "3000",
            currentListeningPorts: [listeningPort()]
        )
        Issue.record("expected killTargetIdentityChanged")
    } catch PortScannerError.killTargetIdentityChanged {
        #expect(PortScannerError.killTargetIdentityChanged.errorDescription?.isEmpty == false)
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}

@Test func killRefusedWhenProcessAlreadyExited() {
    do {
        try PortScanner.ensureKillTargetStillValid(
            expectedStartTime: scanStartTime,
            currentStartTime: nil,
            expectedPort: "3000",
            currentListeningPorts: []
        )
        Issue.record("expected killTargetExited")
    } catch PortScannerError.killTargetExited {
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}

@Test func killRefusedWhenScanBaselineMissing() {
    // 扫描时没拿到启动时间（ps 失败等）就无法验证身份，必须拒绝而不是放行。
    do {
        try PortScanner.ensureKillTargetStillValid(
            expectedStartTime: nil,
            currentStartTime: scanStartTime,
            expectedPort: "3000",
            currentListeningPorts: [listeningPort()]
        )
        Issue.record("expected killIdentityUnavailable")
    } catch PortScannerError.killIdentityUnavailable {
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}

@Test func killRefusedWhenPortNoLongerOwned() {
    // 身份未变但目标端口已不由该进程监听：kill 无法达成目的，拒绝并刷新。
    do {
        try PortScanner.ensureKillTargetStillValid(
            expectedStartTime: scanStartTime,
            currentStartTime: scanStartTime,
            expectedPort: "3000",
            currentListeningPorts: [listeningPort(port: "4000")]
        )
        Issue.record("expected killTargetSocketChanged")
    } catch PortScannerError.killTargetSocketChanged {
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}

@Test func killRefusedWhenProcessStopsListeningEntirely() {
    do {
        try PortScanner.ensureKillTargetStillValid(
            expectedStartTime: scanStartTime,
            currentStartTime: scanStartTime,
            expectedPort: "3000",
            currentListeningPorts: []
        )
        Issue.record("expected killTargetSocketChanged")
    } catch PortScannerError.killTargetSocketChanged {
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}