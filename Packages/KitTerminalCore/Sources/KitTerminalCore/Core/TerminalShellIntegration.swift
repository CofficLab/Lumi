import Foundation

/// Shell 集成
///
/// 为终端会话注入 shell 初始化脚本，实现以下功能：
/// - 自动更新终端标题（显示当前运行的命令）
/// - 正确 source 用户的 shell 配置文件（.zshrc / .bashrc 等）
///
/// 实现原理（以 zsh 为例）：
/// 1. 创建临时目录 /tmp/{username}-lumi-zsh/
/// 2. 将注入脚本复制为 .zshrc / .zprofile / .zlogin / .zshenv
/// 3. 设置 ZDOTDIR=临时目录 → zsh 启动时读取注入的脚本
/// 4. 注入脚本先 source 用户的真实 rc 文件，再安装 preexec/precmd hooks
/// 5. preexec: 设置终端标题为正在执行的命令
/// 6. precmd: 恢复终端标题为 shell 名称
public enum ShellIntegration {
    // MARK: - Errors

    public enum Error: Swift.Error, LocalizedError {
        case zshScriptsNotFound
        case bashScriptNotFound
        case failedToCreateTempDirectory

        public var errorDescription: String? {
            switch self {
            case .zshScriptsNotFound:
                return "Failed to find zsh shell integration scripts."
            case .bashScriptNotFound:
                return "Failed to find bash shell integration script."
            case .failedToCreateTempDirectory:
                return "Failed to create temporary directory for shell integration."
            }
        }
    }

    // MARK: - Environment Variable Names

    private enum Vars {
        static let lumiInjection = "LUMI_INJECTION"
        static let lumiShellLogin = "LUMI_SHELL_LOGIN"
        static let zDotDir = "ZDOTDIR"
        static let ceZDotDir = "LUMI_ZDOTDIR"
        static let userZDotDir = "USER_ZDOTDIR"
    }

    // MARK: - Shell Type

    public enum Shell: String, CaseIterable {
        case bash
        case zsh

        public var defaultPath: String {
            switch self {
            case .bash: return "/bin/bash"
            case .zsh: return "/bin/zsh"
            }
        }
    }

    // MARK: - Setup

    /// 配置 shell 集成的逐会话产物。
    ///
    /// - Parameters:
    ///   - shell: 要启动的 shell 类型
    ///   - baseEnvironment: 进程已有的环境变量，用于读取用户的 ZDOTDIR（#500）
    ///   - useLogin: 是否使用 login shell
    /// - Returns: 需要追加到进程环境的环境变量，与传给 shell 可执行文件的参数
    ///
    /// 集成脚本文件由 `prepareArtifacts` 在后台准备并跨会话复用；本方法只做
    /// 内存中的环境/参数组装，可在主线程安全调用（#1234）。
    public static func setupIntegration(
        for shell: Shell,
        baseEnvironment: [String],
        useLogin: Bool = true
    ) async throws -> ShellIntegrationSetup {
        var additionalEnvironment: [String] = ["\(Vars.lumiInjection)=1"]

        var args: [String] = []

        switch shell {
        case .zsh:
            let tempDir = try await prepareArtifacts(for: .zsh)
            // 保存用户的 ZDOTDIR
            let envZDotDir = baseEnvironment.first(where: { $0.starts(with: "ZDOTDIR=") })?
                .trimmingPrefix("ZDOTDIR=")
            let userHome = NSHomeDirectory()
            let userZDotDir = (envZDotDir?.isEmpty ?? true) ? userHome : String(envZDotDir ?? "")
            additionalEnvironment.append("\(Vars.zDotDir)=\(tempDir.path)")
            additionalEnvironment.append("\(Vars.userZDotDir)=\(userZDotDir)")
            // zsh 参数
            if useLogin {
                args.append("-l")
            }
            args.append("-i")
        case .bash:
            let tempDir = try await prepareArtifacts(for: .bash)
            // bash 3.2（macOS 系统自带）在登录模式（-l）下会忽略 --init-file，
            // 注入脚本完全不执行，标题集成随之失效（issue #346）。登录启动链由
            // 脚本自身在 LUMI_SHELL_LOGIN=1 分支里重放（/etc/profile 与
            // ~/.bash_profile 等），因此这里不能再叠加 -l。
            args.append(contentsOf: ["--init-file", tempDir.appendingPathComponent("lumi_bash_integration.sh").path])
            args.append("-i")
        }

        if useLogin {
            additionalEnvironment.append("\(Vars.lumiShellLogin)=1")
        }

        return ShellIntegrationSetup(
            additionalEnvironment: additionalEnvironment,
            shellArguments: args
        )
    }

    /// 自动检测系统默认 shell
    public static func autoDetectShell() -> Shell {
        let envShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let basename = (envShell as NSString).lastPathComponent
        return Shell(rawValue: basename) ?? .zsh
    }

    /// 补充所选 shell 的 SHELL 并继承用户 ZDOTDIR，供集成脚本恢复原始配置（#500）。
    public static func makeEnvironment(
        base: [String],
        shellPath: String,
        parentEnvironment: [String: String]
    ) -> [String] {
        var env = base
        env.append("TERM_PROGRAM=Lumi_Terminal")
        env.append("TERM=xterm-256color")
        env.append("LANG=en_US.UTF-8")
        env.append("PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")
        env.append("SHELL=\(shellPath)")
        if let zDotDir = parentEnvironment["ZDOTDIR"], !zDotDir.isEmpty {
            env.append("ZDOTDIR=\(zDotDir)")
        }
        return env
    }

    // MARK: - Artifacts

    /// shell 集成的逐会话组装结果（#1234）。
    public struct ShellIntegrationSetup: Sendable {
        /// 追加到进程环境的环境变量
        public let additionalEnvironment: [String]
        /// 传给 shell 可执行文件的参数
        public let shellArguments: [String]
    }

    /// 准备（或复用）shell 集成脚本工件，返回其所在目录。
    ///
    /// 脚本内容只由 shell 类型决定，与具体会话无关：同进程内首次调用在后台
    /// 校验/落盘，之后直接复用磁盘上已有的文件，不再逐会话删除重建、重复
    /// 写入（#1234）。跨进程（如应用升级）时通过内容比对修复过时脚本。
    public static func prepareArtifacts(for shell: Shell) async throws -> URL {
        try await artifactStore.directory(for: shell)
    }

    /// 工件目录（按 shell 类型固定），供测试与诊断使用。
    static func artifactsDirectory(for shell: Shell) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(NSUserName())-lumi-\(shell.rawValue)")
    }

    /// 各 shell 的预期工件：文件名 → 内容。
    static func expectedArtifacts(for shell: Shell) -> [(name: String, content: String)] {
        switch shell {
        case .zsh:
            return [
                (".zshrc", generateZshRcScript()),
                (".zprofile", generateZshProfileScript()),
                (".zlogin", generateZshLoginScript()),
                (".zshenv", generateZshEnvScript()),
            ]
        case .bash:
            return [("lumi_bash_integration.sh", generateBashScript())]
        }
    }

    /// 校验/落盘工件；内容一致则保留原文件，缺失或过时才写入。
    /// 无隔离，仅供 `ArtifactStore` 在后台执行与测试直接调用。
    static func materializeArtifacts(for shell: Shell) throws -> URL {
        let dir = artifactsDirectory(for: shell)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw Error.failedToCreateTempDirectory
        }
        for artifact in expectedArtifacts(for: shell) {
            let fileURL = dir.appendingPathComponent(artifact.name)
            if let existing = try? String(contentsOf: fileURL, encoding: .utf8),
               existing == artifact.content {
                continue
            }
            try artifact.content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return dir
    }

    private static let artifactStore = ArtifactStore()

    /// 工件缓存：同进程内已校验过的目录直接复用，避免每次启动都做磁盘 I/O。
    private actor ArtifactStore {
        private var directories: [Shell: URL] = [:]

        func directory(for shell: Shell) throws -> URL {
            if let cached = directories[shell],
               FileManager.default.fileExists(atPath: cached.path) {
                let names = ShellIntegration.expectedArtifacts(for: shell).map(\.name)
                let missing = names.contains { name in
                    !FileManager.default.fileExists(atPath: cached.appendingPathComponent(name).path)
                }
                if !missing {
                    return cached
                }
            }
            let dir = try ShellIntegration.materializeArtifacts(for: shell)
            directories[shell] = dir
            return dir
        }
    }

    // MARK: - zsh Scripts

    private static func generateZshRcScript() -> String {
        """
        #!/bin/zsh
        # Lumi Shell Integration - zsh rc
        # Source user's real .zshrc, then install preexec/precmd hooks

        # Prevent recursion
        if [ -n "$LUMI_SHELL_INTEGRATION" ]; then
            ZDOTDIR=$USER_ZDOTDIR
            builtin return
        fi

        LUMI_SHELL_INTEGRATION=1

        # Fix HISTFILE to use user's real home
        if [[ "$LUMI_INJECTION" == "1" ]]; then
            HISTFILE=$USER_ZDOTDIR/.zsh_history
        fi

        # Source user's real .zshrc
        if [[ "$LUMI_INJECTION" == "1" ]]; then
            if [[ -f $USER_ZDOTDIR/.zshrc ]]; then
                LUMI_ZDOTDIR=$ZDOTDIR
                ZDOTDIR=$USER_ZDOTDIR
                . $USER_ZDOTDIR/.zshrc
            fi
        fi

        # Install hooks
        builtin autoload -Uz add-zsh-hook

        __lumi_preexec() {
            builtin printf "\\033]0;%s\\007" "$1"
        }

        __lumi_precmd() {
            builtin printf "\\033]0;zsh\\007"
        }

        add-zsh-hook preexec __lumi_preexec
        add-zsh-hook precmd __lumi_precmd

        # Restore ZDOTDIR
        if [[ $USER_ZDOTDIR != $LUMI_ZDOTDIR ]]; then
            ZDOTDIR=$USER_ZDOTDIR
        fi
        """
    }

    private static func generateZshProfileScript() -> String {
        """
        #!/bin/zsh
        # Lumi Shell Integration - zsh profile

        if [[ -f $USER_ZDOTDIR/.zprofile ]]; then
            . $USER_ZDOTDIR/.zprofile
        fi
        """
    }

    private static func generateZshLoginScript() -> String {
        """
        #!/bin/zsh
        # Lumi Shell Integration - zsh login

        if [[ -f $USER_ZDOTDIR/.zlogin ]]; then
            . $USER_ZDOTDIR/.zlogin
        fi
        """
    }

    private static func generateZshEnvScript() -> String {
        """
        #!/bin/zsh
        # Lumi Shell Integration - zsh env

        if [[ -f $USER_ZDOTDIR/.zshenv ]]; then
            . $USER_ZDOTDIR/.zshenv
        fi
        """
    }

    // MARK: - bash Script

    private static func generateBashScript() -> String {
        """
        #!/bin/bash
        # Lumi Shell Integration - bash

        # Prevent recursion
        if [[ -n "${LUMI_SHELL_INTEGRATION}" ]]; then
            builtin return
        fi

        LUMI_SHELL_INTEGRATION=1

        # Source user's init files
        if [[ "$LUMI_INJECTION" == "1" ]]; then
            if [[ -z "$LUMI_SHELL_LOGIN" ]]; then
                if [[ -r ~/.bashrc ]]; then
                    . ~/.bashrc
                fi
            else
                if [[ -r /etc/profile ]]; then
                    . /etc/profile
                fi
                if [[ -r ~/.bash_profile ]]; then
                    . ~/.bash_profile
                elif [[ -r ~/.bash_login ]]; then
                    . ~/.bash_login
                elif [[ -r ~/.profile ]]; then
                    . ~/.profile
                fi
                builtin unset LUMI_SHELL_LOGIN
            fi
            builtin unset LUMI_INJECTION
        fi

        # Install hooks using PROMPT_COMMAND and DEBUG trap
        __lumi_preexec() {
            builtin printf "\\033]0;%s\\007" "$BASH_COMMAND"
        }

        __lumi_precmd() {
            builtin printf "\\033]0;bash\\007"
        }

        # Use PROMPT_COMMAND for precmd-like behavior
        if [[ -z "$PROMPT_COMMAND" ]]; then
            PROMPT_COMMAND='__lumi_precmd'
        else
            PROMPT_COMMAND='__lumi_precmd;'$PROMPT_COMMAND
        fi

        # Use DEBUG trap for preexec-like behavior
        trap '__lumi_preexec' DEBUG
        """
    }
}

// MARK: - String Helper

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        if hasPrefix(prefix) {
            return String(dropFirst(prefix.count))
        }
        return self
    }
}