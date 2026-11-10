#if os(macOS)
import Darwin
import Foundation

/// 把 nettop 输出的进程名补全为可执行文件的完整 basename。
///
/// nettop 会把进程名截断到 15 个字符（例如 `com.apple.WebKi`、`Trae CN Helper `），
/// 若直接用截断名做聚合键，不同进程会被错误合并成一行。这里按 PID 查询
/// `proc_pidpath`，用完整可执行文件名代替截断名；查询失败时回退原值。
struct ProcessNameResolver {
    typealias NameProvider = (Int) -> String?

    private let nameProvider: NameProvider
    private var cache: [Int: String] = [:]

    init(nameProvider: @escaping NameProvider = ProcessNameResolver.executableName) {
        self.nameProvider = nameProvider
    }

    mutating func resolve(pid: Int, fallback: String) -> String {
        if let cached = cache[pid] {
            return cached
        }

        let name = nameProvider(pid) ?? fallback
        cache[pid] = name
        return name
    }

    mutating func removeAll() {
        cache.removeAll()
    }

    static func executableName(for pid: Int) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let result = proc_pidpath(Int32(pid), &buffer, UInt32(buffer.count))
        guard result > 0 else { return nil }

        let path = String(cString: buffer)
        guard !path.isEmpty else { return nil }

        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }
}
#else
import Foundation

/// 非 macOS 平台不支持 nettop，直接回退到 nettop 原名。
struct ProcessNameResolver {
    typealias NameProvider = (Int) -> String?

    private let nameProvider: NameProvider
    private var cache: [Int: String] = [:]

    init(nameProvider: @escaping NameProvider = { _ in nil }) {
        self.nameProvider = nameProvider
    }

    mutating func resolve(pid: Int, fallback: String) -> String {
        if let cached = cache[pid] {
            return cached
        }
        let name = nameProvider(pid) ?? fallback
        cache[pid] = name
        return name
    }

    mutating func removeAll() {
        cache.removeAll()
    }
}
#endif
