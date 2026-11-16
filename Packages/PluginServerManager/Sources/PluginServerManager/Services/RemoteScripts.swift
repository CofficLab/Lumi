import Foundation

/// 固定的远端采集脚本。
///
/// 全部是常量，不接受任何用户输入拼接，避免命令注入。
/// 输出用 `===SECTION===` 标记分段，由 `ServerMetricsParser` 纯函数解析。
/// 兼容 Linux（procps / coreutils）与 macOS（BSD 工具回退）。
public enum RemoteScripts {
    /// 指标采集：OS / 主机名 / 运行时长 / 负载 / 核数 / 内存 / 磁盘 / CPU。
    ///
    /// CPU 通过 `/proc/stat` 间隔 1 秒的两次采样计算差值（仅 Linux）；
    /// 其他平台拿不到 CPU 百分比时该段为空，解析结果为 nil。
    public static let metrics = """
    echo '===OS==='
    uname -sr
    echo '===HOST==='
    hostname
    echo '===UPTIME==='
    uptime
    echo '===LOAD==='
    (cat /proc/loadavg 2>/dev/null || sysctl -n vm.loadavg 2>/dev/null)
    echo '===CORES==='
    (nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null)
    echo '===MEM==='
    (free -b 2>/dev/null | awk '/^Mem:/ {print $2, $7}')
    echo '===DISK==='
    df -P -k / 2>/dev/null | tail -1
    echo '===CPU==='
    if [ -r /proc/stat ]; then head -1 /proc/stat; sleep 1; head -1 /proc/stat; fi
    echo '===END==='
    """

    /// 进程列表：按 CPU 降序，最多 20 条。
    /// Linux 用 `--sort=-pcpu`；macOS 的 ps 不支持该参数，回退 `-r`。
    public static let processes = """
    if ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu >/dev/null 2>&1; then
      ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu | head -21
    else
      ps -axo pid,user,pcpu,pmem,comm -r | head -21
    fi
    """

    /// 容器列表（含已停止）。输出为制表符分隔：名称 / 镜像 / 状态 / 描述。
    public static let containers = """
    docker ps -a --format '{{.Names}}\\t{{.Image}}\\t{{.State}}\\t{{.Status}}'
    """

    /// 结束进程。pid 已由调用方校验为合法整数，直接内插安全。
    public static func kill(pid: Int, force: Bool) -> String {
        "kill -\(force ? 9 : 15) \(pid)"
    }

    /// 容器动作。name 已由 `ServerContainer.isValidName` 校验（仅字母数字与 `_.-`）。
    public static func container(action: ServerContainerAction, name: String) -> String {
        "docker \(action.rawValue) '\(name)'"
    }
}

/// 允许的容器动作。
public enum ServerContainerAction: String, CaseIterable, Sendable {
    case start
    case stop
    case restart
}