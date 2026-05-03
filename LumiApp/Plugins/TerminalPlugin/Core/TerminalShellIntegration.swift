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
enum ShellIntegration {
    // MARK: - Errors

    enum Error: Swift.Error, LocalizedError {
        case zshScriptsNotFound
        case bashScriptNotFound
        case failedToCreateTempDirectory

        var errorDescription: String? {
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

    enum Shell: String, CaseIterable {
        case bash
        case zsh

        var defaultPath: String {
            switch self {
            case .bash: return "/bin/bash"
            case .zsh: return "/bin/zsh"
            }
        }
    }

    // MARK: - Setup

    /// 配置 shell 集成
    ///
    /// - Parameters:
    ///   - shell: 要启动的 shell 类型
    ///   - environment: 环境变量数组（会被修改）
    ///   - useLogin: 是否使用 login shell
    /// - Returns: 传递给 shell 可执行文件的参数
    static func setupIntegration(
        for shell: Shell,
        environment: inout [String],
        useLogin: Bool = true
    ) throws -> [String] {
        environment.append("\(Vars.lumiInjection)=1")

        var args: [String] = []

        switch shell {
        case .zsh:
            try setupZsh(environment: &environment)
            // zsh 参数
            if useLogin {
                args.append("-l")
            }
            args.append("-i")
        case .bash:
            try setupBash(&args)
            // bash 参数
            if useLogin {
                args.append("-l")
            }
            args.append("-i")
        }

        if useLogin {
            environment.append("\(Vars.lumiShellLogin)=1")
        }

        return args
    }

    /// 自动检测系统默认 shell
    static func autoDetectShell() -> Shell {
        let envShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let basename = (envShell as NSString).lastPathComponent
        return Shell(rawValue: basename) ?? .zsh
    }

    // MARK: - zsh Setup

    private static func setupZsh(environment: inout [String]) throws {
        // 生成注入脚本内容
        let rcScript = generateZshRcScript()
        let profileScript = generateZshProfileScript()
        let loginScript = generateZshLoginScript()
        let envScript = generateZshEnvScript()

        // 创建临时目录
        let tempDir = try makeTempDir(forShell: .zsh)

        // 保存用户的 ZDOTDIR
        let envZDotDir = environment.first(where: { $0.starts(with: "ZDOTDIR=") })?
            .trimmingPrefix("ZDOTDIR=")
        let userHome = NSHomeDirectory()
        let userZDotDir = (envZDotDir?.isEmpty ?? true) ? userHome : String(envZDotDir ?? "")

        environment.append("\(Vars.zDotDir)=\(tempDir.path)")
        environment.append("\(Vars.userZDotDir)=\(userZDotDir)")

        // 写入注入脚本
        try rcScript.write(to: tempDir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        try profileScript.write(to: tempDir.appendingPathComponent(".zprofile"), atomically: true, encoding: .utf8)
        try loginScript.write(to: tempDir.appendingPathComponent(".zlogin"), atomically: true, encoding: .utf8)
        try envScript.write(to: tempDir.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
    }

    // MARK: - bash Setup

    private static func setupBash(_ args: inout [String]) throws {
        // bash 使用 --init-file 注入
        let script = generateBashScript()
        let tempDir = try makeTempDir(forShell: .bash)
        let scriptURL = tempDir.appendingPathComponent("lumi_bash_integration.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        args.append(contentsOf: ["--init-file", scriptURL.path])
    }

    // MARK: - Temp Directory

    private static func makeTempDir(forShell shell: Shell) throws -> URL {
        let username = NSUserName()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(username)-lumi-\(shell.rawValue)")

        // 清理旧的目录
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
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
