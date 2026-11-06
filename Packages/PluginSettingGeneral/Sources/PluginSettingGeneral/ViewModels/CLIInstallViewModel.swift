import Foundation
import KitLumiCLI
import LumiLoggingKit
import os

/// 「命令行工具」分组的视图模型。
///
/// 负责查询 CLI 安装状态、执行安装与卸载，并把结果转成可直接展示的
/// 状态描述。视图层只依赖本类型，不直接调用 `CLIInstaller`。
///
/// 安装状态查询与安装/卸载都会阻塞（需要解析用户的终端 `PATH` 并读写
/// 磁盘），因此全部在后台线程执行，主线程只负责更新展示状态。
@MainActor
final class CLIInstallViewModel: ObservableObject {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.setting-general",
        category: "CLIInstall"
    )

    /// 是否输出详细日志。
    nonisolated static let verbose = false

    /// 安装状态描述。
    enum Status: Equatable {
        /// 尚未确定（正在检查）。
        case checking
        /// 未安装。
        case notInstalled
        /// 已安装，且目标目录在用户的终端 `PATH` 中。
        case installed(path: String)
        /// 已安装，但目标目录不在 `PATH` 中，需要用户自行加入。
        case installedNotOnPath(path: String, directory: String)

        /// 是否已安装。
        var isInstalled: Bool {
            switch self {
            case .checking, .notInstalled: false
            case .installed, .installedNotOnPath: true
            }
        }
    }

    /// 当前状态。
    @Published private(set) var status: Status = .checking

    /// 是否正在检查或变更安装状态（用于禁用按钮、显示进度态）。
    @Published private(set) var isBusy = false

    /// 最近一次操作的错误描述；`nil` 表示没有错误。
    @Published private(set) var lastError: String?

    /// 安装器接口，便于测试注入替身。
    private let installer: any CLIInstalling

    init(installer: any CLIInstalling = LiveCLIInstaller()) {
        self.installer = installer
        // 预热 PATH 解析缓存（首次解析需要启动登录 shell，耗时约 1~2 秒）。
        // 放在后台，避免首次进入设置页时卡顿。
        Task.detached(priority: .utility) {
            CLIPathResolver.prewarm()
        }
        refresh()
    }

    /// 重新读取安装状态。
    func refresh() {
        status = .checking
        run(label: "检查命令行工具状态") { [installer] in
            installer.status()
        } onSuccess: { [weak self] installation in
            self?.apply(installation)
        }
    }

    /// 执行安装。
    ///
    /// 安装到**已在用户终端 `PATH` 中且可写**的目录；找不到时回落到
    /// `~/.local/bin` 并在状态里提示用户自行加入 `PATH`。
    func install() {
        lastError = nil
        run(label: "安装命令行工具") { [installer] in
            installer.install()
        } onSuccess: { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .installed:
                if Self.verbose {
                    Self.logger.info("命令行工具安装完成")
                }
                self.refresh()
            case .installedButNotOnPath(let target):
                if Self.verbose {
                    Self.logger.info(
                        "命令行工具已安装到 \(target.directory.path, privacy: .public)，但该目录不在 PATH 中"
                    )
                }
                self.refresh()
            case .failed(let reason):
                Self.logger.error("命令行工具安装失败：\(reason, privacy: .public)")
                self.lastError = reason
                self.status = .notInstalled
            }
        }
    }

    /// 执行卸载。
    func uninstall() {
        lastError = nil
        run(label: "卸载命令行工具") { [installer] in
            installer.uninstall()
        } onSuccess: { [weak self] removed in
            guard let self else { return }
            if removed {
                if Self.verbose {
                    Self.logger.info("命令行工具已卸载")
                }
                self.refresh()
            } else {
                Self.logger.error("命令行工具卸载失败")
                self.lastError = "uninstallFailed"
            }
        }
    }

    // MARK: - Private Helpers

    /// 在后台线程执行阻塞操作，主线程只接收结果。
    ///
    /// - Parameters:
    ///   - label: 日志标签。
    ///   - operation: 阻塞操作（在后台线程执行）。
    ///   - onSuccess: 主线程上的结果回调。
    private func run<T: Sendable>(
        label: String,
        operation: @escaping @Sendable () -> T,
        onSuccess: @escaping @MainActor (T) -> Void
    ) {
        isBusy = true
        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                operation()
            }.value
            guard let self else { return }
            self.isBusy = false
            onSuccess(result)
        }
    }

    /// 把安装状态应用到展示状态。
    private func apply(_ installation: CLIInstallationStatus) {
        if let installedPath = installation.installedPath {
            let path = installedPath.path
            if installation.isOnPath {
                status = .installed(path: path)
            } else {
                let directory = installedPath
                    .deletingLastPathComponent()
                    .standardizedFileURL
                    .path
                status = .installedNotOnPath(path: path, directory: directory)
            }
        } else {
            status = .notInstalled
        }
    }
}

/// `CLIInstaller` 的抽象接口，便于测试注入替身。
protocol CLIInstalling: AnyObject, Sendable {
    func status() -> CLIInstallationStatus
    func install() -> CLIInstallOutcome
    func uninstall() -> Bool
}

/// 走真实文件系统的 `CLIInstaller` 实现。
final class LiveCLIInstaller: CLIInstalling, @unchecked Sendable {
    func status() -> CLIInstallationStatus {
        CLIInstaller.status()
    }

    func install() -> CLIInstallOutcome {
        CLIInstaller.install()
    }

    func uninstall() -> Bool {
        CLIInstaller.uninstall()
    }
}
