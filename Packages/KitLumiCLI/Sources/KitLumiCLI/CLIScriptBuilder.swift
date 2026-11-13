import Foundation

/// 生成 `lumi` CLI 脚本的内容。
///
/// 脚本本身不依赖 App bundle 里的任何资源：它只负责把目标目录编码进
/// `lumi://finder/open-project?path=...` 并交给 macOS Launch Services，
/// 由 Lumi 完成「打开目录为当前项目」。
///
/// App 路径通过 `LUMI_APP` 环境变量或默认安装位置解析，因此在 App 升级、
/// 迁移到别的目录后仍然可用。
public enum CLIScriptBuilder {
    /// CLI 命令名。
    public static let commandName = "lumi"

    /// 默认 URL scheme。
    ///
    /// - Note: scheme 随构建配置变化（Release 为 `lumi`，Debug 为 `lumi-debug`），
    ///   安装时会把实际 scheme 写进脚本；该常量仅作兜底。
    public static let defaultURLScheme = "lumi"

    /// 显式指定 App 路径的环境变量名。
    public static let appPathEnvironmentKey = "LUMI_APP"

    /// 生成脚本内容。
    ///
    /// - Parameters:
    ///   - commandName: 命令名（默认 `lumi`）。
    ///   - urlScheme: URL scheme 兜底值（默认 `lumi`）。
    ///   - appPath: 安装时记录的应用路径；脚本优先用它，再用常见安装位置兜底。
    /// - Returns: 可直接写入磁盘的 shell 脚本内容（以换行结尾）。
    public static func scriptContents(
        commandName: String = commandName,
        urlScheme: String = defaultURLScheme,
        appPath: String? = nil
    ) -> String {
        let embeddedAppPath = shellSingleQuoted(appPath ?? "")
        return """
        #!/bin/sh
        #
        # \(commandName) — 在 Lumi 中打开当前目录（或指定目录）。
        #
        # 用法：
        #   \(commandName)            # 打开当前工作目录
        #   \(commandName) .          # 打开当前工作目录
        #   \(commandName) <path>     # 打开指定目录
        #
        # 由 Lumi.app 的「设置 → 通用 → 命令行工具」自动安装。
        # 本脚本不依赖 App bundle 内的任何文件。

        set -eu

        # --- 定位 Lumi.app -------------------------------------------------------
        # 规则：
        # - 设置了 \(appPathEnvironmentKey) 时**只**用它（显式覆盖，便于多版本共存）；
        # - 否则依次尝试安装时记录的路径与常见安装位置。
        find_lumi_app() {
            if [ -n "${LUMI_APP:-}" ]; then
                if [ -d "${LUMI_APP}" ]; then
                    printf '%s' "${LUMI_APP}"
                    return 0
                fi
                return 1
            fi
            for candidate in \\
                \(embeddedAppPath) \\
                "/Applications/Lumi.app" \\
                "$HOME/Applications/Lumi.app"
            do
                if [ -n "$candidate" ] && [ -d "$candidate" ]; then
                    printf '%s' "$candidate"
                    return 0
                fi
            done
            return 1
        }

        APP_PATH="$(find_lumi_app || true)"
        if [ -z "$APP_PATH" ]; then
            echo "\(commandName): 未找到 Lumi.app，请先安装 Lumi 或设置 \(appPathEnvironmentKey) 环境变量。" >&2
            exit 1
        fi

        # --- 解析 URL scheme ----------------------------------------------------
        # scheme 随构建配置变化（Release 用 lumi，Debug 用 lumi-debug），因此从
        # App 的 Info.plist 读取；读取失败时回落到安装时记录的值。
        read_url_scheme() {
            if [ -f "${1}/Contents/Info.plist" ]; then
                scheme="$(/usr/libexec/PlistBuddy -c "Print :LumiURLScheme" "${1}/Contents/Info.plist" 2>/dev/null || true)"
                if [ -n "$scheme" ]; then
                    printf '%s' "$scheme"
                    return 0
                fi
            fi
            return 1
        }

        URL_SCHEME="$(read_url_scheme "$APP_PATH" || true)"
        if [ -z "$URL_SCHEME" ]; then
            URL_SCHEME="\(urlScheme)"
        fi

        # --- 解析目标目录 ---------------------------------------------------------
        TARGET="${1:-.}"

        # 展开 ~ 并转成绝对路径。
        case "$TARGET" in
            "~") TARGET="$HOME" ;;
            "~/"*) TARGET="$HOME/${TARGET#\\~/}" ;;
        esac

        if [ ! -e "$TARGET" ]; then
            echo "\(commandName): 路径不存在：$TARGET" >&2
            exit 1
        fi

        ABS_TARGET="$(cd "$TARGET" 2>/dev/null && pwd -P || printf '%s' "$TARGET")"

        # --- 编码为 URL -----------------------------------------------------------
        # 手工百分号编码，保证路径中的空格、#、&、中文等字符都能安全通过
        # query 传递。不依赖 URI::Escape 等非核心 perl 模块。
        urlencode() {
            printf '%s' "$1" | /usr/bin/perl -ne 'chomp; s/([^A-Za-z0-9._~-])/sprintf("%%%02X", ord($1))/ge; print'
        }

        ENCODED_PATH="$(urlencode "$ABS_TARGET")"
        TARGET_URL="${URL_SCHEME}://finder/open-project?path=${ENCODED_PATH}"

        # --- 交给 Launch Services 打开 -------------------------------------------
        # -g 后台启动，不打断当前终端。
        #
        # 路由方式：显式用 -a 指定 App。同一 scheme 可能被多个构建（Release /
        # Debug）注册，交给系统路由会投递到不确定的实例；显式指定可保证投递到
        # 装了这个脚本的 App。
        if ! /usr/bin/open -g -a "$APP_PATH" "$TARGET_URL"; then
            echo "\(commandName): 无法打开 Lumi（${TARGET_URL}）" >&2
            exit 1
        fi

        exit 0

        """
    }

    /// 把任意字符串编码为 POSIX shell 单引号字面量。
    ///
    /// 单引号内除 `'` 外所有字符都按字面处理（`$`、反引号、`"`、`\` 都不展开），
    /// 唯一的例外 `'` 用 `'\''` 拼接。安装路径里的合法特殊字符因此不会被 shell
    /// 展开或改写（#142）。
    static func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
