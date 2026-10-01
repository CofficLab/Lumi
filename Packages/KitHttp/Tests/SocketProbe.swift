import Darwin
import Foundation

/// 按 socket 归属精确统计 fd，排除「同进程内 loopback 服务器」造成的测量干扰。
///
/// 同进程内既有客户端 socket，也有服务端 accept 出来的 socket。二者可以靠端口区分：
/// - 客户端 socket：远端端口 == 服务器监听端口
/// - 服务端 socket：本地端口 == 服务器监听端口
///
/// 因此只统计「远端端口等于服务器端口」的 socket，即可精确得到客户端连接数，
/// 不受服务端 fd 数量变化影响。
enum SocketProbe {

    /// 统计远端端口等于 `peerPort` 的 socket 数量（即客户端侧连接）。
    static func clientSocketCount(peerPort: UInt16) -> Int {
        let pid = getpid()
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return -1 }

        let capacity = Int(needed) / MemoryLayout<proc_fdinfo>.stride + 16
        var buffer = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
        let got = proc_pidinfo(
            pid,
            PROC_PIDLISTFDS,
            0,
            &buffer,
            Int32(capacity * MemoryLayout<proc_fdinfo>.stride)
        )
        guard got > 0 else { return -1 }
        let count = Int(got) / MemoryLayout<proc_fdinfo>.stride

        var matched = 0
        for index in 0..<count where Int(buffer[index].proc_fdtype) == Int(PROX_FDTYPE_SOCKET) {
            let fd = buffer[index].proc_fd
            var info = socket_fdinfo()
            let size = Int32(MemoryLayout<socket_fdinfo>.size)
            let ok = withUnsafeMutablePointer(to: &info) { pointer in
                proc_pidfdinfo(pid, fd, PROC_PIDFDSOCKETINFO, pointer, size)
            }
            guard ok == size else { continue }

            // 仅处理 TCP；远端端口匹配服务器监听端口即为客户端连接。
            guard info.psi.soi_kind == SOCKINFO_TCP else { continue }
            let rawPort = UInt32(bitPattern: info.psi.soi_proto.pri_tcp.tcpsi_ini.insi_fport) & 0xFFFF
            let remotePort = UInt16(bigEndian: UInt16(rawPort))
            if remotePort == peerPort { matched += 1 }
        }
        return matched
    }
}
