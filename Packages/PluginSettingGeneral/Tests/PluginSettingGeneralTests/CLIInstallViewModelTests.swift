import Foundation
import KitLumiCLI
import Testing
@testable import PluginSettingGeneral

/// 记录调用并可编排返回值的安装器替身。
///
/// 放在文件作用域而非嵌套在测试套件内：`Scripts/extract-testplan-metadata.py`
/// 会把套件内嵌套的类型误认成新的测试套件。
final class StubCLIInstaller: CLIInstalling, @unchecked Sendable {
    var statusResult: CLIInstallationStatus
    var installResult: CLIInstallOutcome
    var uninstallResult: Bool

    private(set) var statusCallCount = 0
    private(set) var installCallCount = 0
    private(set) var uninstallCallCount = 0

    init(
        status: CLIInstallationStatus = CLIInstallationStatus(
            installedPath: nil,
            isOnPath: false,
            suggestedTarget: nil
        ),
        install: CLIInstallOutcome = .failed(reason: "stub"),
        uninstall: Bool = true
    ) {
        self.statusResult = status
        self.installResult = install
        self.uninstallResult = uninstall
    }

    func status() -> CLIInstallationStatus {
        statusCallCount += 1
        return statusResult
    }

    func install() -> CLIInstallOutcome {
        installCallCount += 1
        return installResult
    }

    func uninstall() -> Bool {
        uninstallCallCount += 1
        return uninstallResult
    }
}

/// `CLIInstallViewModel` 的状态与操作测试。
///
/// 用替身注入 `CLIInstalling`，不触碰真实文件系统。
@Suite("CLIInstallViewModel")
@MainActor
struct CLIInstallViewModelTests {

    /// 等待条件成立（按时间给预算，不用固定 sleep）。
    private func waitUntil(
        _ condition: () -> Bool,
        timeout: TimeInterval = 5
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - 初始状态

    @Test("未安装时状态为 notInstalled")
    func initialStatusIsNotInstalled() async {
        let installer = StubCLIInstaller()
        let model = CLIInstallViewModel(installer: installer)

        await waitUntil { model.status == .notInstalled }

        #expect(model.status == .notInstalled)
        #expect(!model.status.isInstalled)
        #expect(model.lastError == nil)
    }

    @Test("已安装且在 PATH 中时状态为 installed")
    func installedStatusWhenOnPath() async {
        let path = URL(fileURLWithPath: "/opt/homebrew/bin/lumi")
        let installer = StubCLIInstaller(
            status: CLIInstallationStatus(
                installedPath: path,
                isOnPath: true,
                suggestedTarget: nil
            )
        )
        let model = CLIInstallViewModel(installer: installer)

        await waitUntil { model.status.isInstalled }

        #expect(model.status == .installed(path: path.path))
        #expect(model.status.isInstalled)
    }

    @Test("已安装但不在 PATH 中时状态带目录提示")
    func installedNotOnPathStatusCarriesDirectory() async {
        let path = URL(fileURLWithPath: "/Users/test/.local/bin/lumi")
        let installer = StubCLIInstaller(
            status: CLIInstallationStatus(
                installedPath: path,
                isOnPath: false,
                suggestedTarget: nil
            )
        )
        let model = CLIInstallViewModel(installer: installer)

        await waitUntil { model.status.isInstalled }

        #expect(model.status == .installedNotOnPath(
            path: path.path,
            directory: "/Users/test/.local/bin"
        ))
        #expect(model.status.isInstalled)
    }

    @Test("状态检查完成前处于 checking 状态")
    func statusIsCheckingWhileResolving() {
        let installer = StubCLIInstaller()
        let model = CLIInstallViewModel(installer: installer)

        // init() 之后的瞬间状态为 checking（尚未拿到结果）。
        #expect(model.status == .checking)
        #expect(!model.status.isInstalled)
    }

    // MARK: - 安装

    @Test("install 成功后刷新为已安装状态")
    func installSucceedsThenRefreshesStatus() async {
        let path = URL(fileURLWithPath: "/opt/homebrew/bin/lumi")
        let installer = StubCLIInstaller(
            status: CLIInstallationStatus(
                installedPath: nil,
                isOnPath: false,
                suggestedTarget: nil
            ),
            install: .installed(
                target: CLIInstallTarget(
                    directory: URL(fileURLWithPath: "/opt/homebrew/bin"),
                    isOnPath: true,
                    isWritable: true
                )
            )
        )
        let model = CLIInstallViewModel(installer: installer)

        model.install()
        await waitUntil { installer.installCallCount == 1 }

        // 安装后 install() 内部会再 refresh 一次；让状态切到已安装。
        installer.statusResult = CLIInstallationStatus(
            installedPath: path,
            isOnPath: true,
            suggestedTarget: nil
        )
        model.refresh()
        await waitUntil { model.status.isInstalled }

        #expect(model.status == .installed(path: path.path))
        #expect(model.lastError == nil)
    }

    @Test("安装失败时记录错误且不改变安装状态")
    func installFailureRecordsError() async {
        let installer = StubCLIInstaller(
            install: .failed(reason: "Directory is not writable: /usr/bin")
        )
        let model = CLIInstallViewModel(installer: installer)

        model.install()
        await waitUntil { model.lastError != nil }

        #expect(model.lastError == "Directory is not writable: /usr/bin")
        #expect(!model.status.isInstalled)
    }

    @Test("安装到不在 PATH 的目录时仍算已安装")
    func installButNotOnPathStillInstalled() async {
        let installer = StubCLIInstaller(
            install: .installedButNotOnPath(
                target: CLIInstallTarget(
                    directory: URL(fileURLWithPath: "/Users/test/.local/bin"),
                    isOnPath: false,
                    isWritable: true
                )
            )
        )
        let model = CLIInstallViewModel(installer: installer)

        model.install()
        await waitUntil { installer.installCallCount == 1 }

        #expect(model.lastError == nil)
    }

    // MARK: - 卸载

    @Test("uninstall 成功后刷新为未安装状态")
    func uninstallSucceedsThenRefreshesStatus() async {
        let path = URL(fileURLWithPath: "/opt/homebrew/bin/lumi")
        let installer = StubCLIInstaller(
            status: CLIInstallationStatus(
                installedPath: path,
                isOnPath: true,
                suggestedTarget: nil
            ),
            uninstall: true
        )
        let model = CLIInstallViewModel(installer: installer)
        await waitUntil { model.status.isInstalled }

        model.uninstall()
        await waitUntil { installer.uninstallCallCount == 1 }

        installer.statusResult = CLIInstallationStatus(
            installedPath: nil,
            isOnPath: false,
            suggestedTarget: nil
        )
        model.refresh()
        await waitUntil { !model.status.isInstalled }

        #expect(!model.status.isInstalled)
        #expect(model.lastError == nil)
    }

    @Test("卸载失败时记录错误")
    func uninstallFailureRecordsError() async {
        let installer = StubCLIInstaller(uninstall: false)
        let model = CLIInstallViewModel(installer: installer)

        model.uninstall()
        await waitUntil { model.lastError != nil }

        #expect(model.lastError == "uninstallFailed")
    }

    // MARK: - 并发状态

    @Test("忙碌标志在操作结束后复位")
    func busyFlagResetsAfterOperation() async {
        let installer = StubCLIInstaller()
        let model = CLIInstallViewModel(installer: installer)

        model.install()
        await waitUntil { installer.installCallCount == 1 && !model.isBusy }

        #expect(!model.isBusy)
    }
}
